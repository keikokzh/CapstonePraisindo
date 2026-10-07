-- ============================================================
-- 11_resolver_functions.sql — Fee Formula resolver functions
--
-- Reconstructed fresh for this schema version (the original
-- implementations from an earlier session are not available here).
-- Behavior follows the Fee Formula design documented in
-- urs2026-postgresql-schema.md / urs2026-data-model.md:
--   fee_formula       = the FORMULA ("what": rate structure)
--   product_fee_formula / agent_fee_formula = the ASSIGNMENT ("who/when")
--
-- rate columns (flat_rate, fee_formula_tier.rate) are stored as plain
-- decimal fractions (e.g. 0.0150 = 1.50%), not percentages.
-- ============================================================

-- ------------------------------------------------------------
-- get_fee_rate: resolve the effective rate for ONE formula given
-- an amount (for TIERED/TIERED_PROGRESSIVE) and, for calc_method
-- DSC, a holding-period in days (declining sales charge — tiers
-- are then interpreted as day ranges, not amount ranges).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_fee_rate(
    p_formula_id   UUID,
    p_amount       NUMERIC DEFAULT NULL,
    p_holding_days INTEGER DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
    f_pricing_model pricing_model_enum;
    f_calc_method   calc_method_enum;
    f_flat_rate     NUMERIC;
    v_basis         NUMERIC;
    v_rate          NUMERIC;
BEGIN
    SELECT pricing_model, calc_method, flat_rate
      INTO f_pricing_model, f_calc_method, f_flat_rate
      FROM fee_formula
     WHERE formula_id = p_formula_id;

    IF f_pricing_model IS NULL THEN
        RAISE EXCEPTION 'get_fee_rate: fee_formula % not found', p_formula_id;
    END IF;

    IF f_pricing_model = 'FLAT' THEN
        RETURN f_flat_rate;
    END IF;

    -- TIERED / TIERED_PROGRESSIVE both need a basis value to look up a band.
    -- DSC (declining sales charge) uses holding days as the basis;
    -- otherwise the basis is the transaction amount.
    IF f_calc_method = 'DSC' THEN
        v_basis := p_holding_days;
        IF v_basis IS NULL THEN
            RAISE EXCEPTION 'get_fee_rate: formula % uses calc_method DSC and requires p_holding_days', p_formula_id;
        END IF;
    ELSIF f_calc_method = 'FIFO' THEN
        -- FIFO (lot-based) fees need per-lot holding history that this
        -- schema does not track at the order_txn level (units are
        -- recorded in aggregate, not per purchase lot). A correct FIFO
        -- rate cannot be resolved from fee_formula/fee_formula_tier
        -- alone — this is a documented limitation, not a silent
        -- approximation. Raise rather than return a wrong number.
        RAISE EXCEPTION 'get_fee_rate: formula % uses calc_method FIFO — lot-level holdings are not modeled in this schema; resolve FIFO fees at the application layer using order-level lot data', p_formula_id;
    ELSE
        v_basis := p_amount;
        IF v_basis IS NULL THEN
            RAISE EXCEPTION 'get_fee_rate: formula % is tiered by amount and requires p_amount', p_formula_id;
        END IF;
    END IF;

    IF f_pricing_model = 'TIERED' THEN
        -- single-band lookup: the band the basis falls into applies to
        -- the whole amount.
        SELECT rate INTO v_rate
          FROM fee_formula_tier
         WHERE formula_id = p_formula_id
           AND tier_from <= v_basis
           AND (tier_to IS NULL OR v_basis < tier_to)
         ORDER BY tier_from DESC
         LIMIT 1;

        IF v_rate IS NULL THEN
            RAISE EXCEPTION 'get_fee_rate: no fee_formula_tier band covers basis % for formula %', v_basis, p_formula_id;
        END IF;
        RETURN v_rate;
    END IF;

    IF f_pricing_model = 'TIERED_PROGRESSIVE' THEN
        -- progressive: blended effective rate, bracket by bracket
        -- (like a tax bracket), returned as a single effective rate
        -- = total_fee / basis so callers can keep using rate * amount.
        DECLARE
            v_tier       RECORD;
            v_total_fee  NUMERIC := 0;
            v_band_amt   NUMERIC;
        BEGIN
            FOR v_tier IN
                SELECT tier_from, tier_to, rate
                  FROM fee_formula_tier
                 WHERE formula_id = p_formula_id
                 ORDER BY tier_from ASC
            LOOP
                EXIT WHEN v_tier.tier_from >= v_basis;
                v_band_amt := LEAST(v_basis, COALESCE(v_tier.tier_to, v_basis)) - v_tier.tier_from;
                IF v_band_amt > 0 THEN
                    v_total_fee := v_total_fee + v_band_amt * v_tier.rate;
                END IF;
            END LOOP;

            IF v_basis = 0 THEN
                RETURN 0;
            END IF;
            RETURN v_total_fee / v_basis;
        END;
    END IF;

    RAISE EXCEPTION 'get_fee_rate: unhandled pricing_model % for formula %', f_pricing_model, p_formula_id;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- calculate_product_fee: resolve the applicable product_fee_formula
-- assignment (product-specific first, falling back to the Global
-- assignment where product_id IS NULL) as of a given date, then
-- apply its rate to the amount.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_product_fee(
    p_product_id   UUID,
    p_fee_type     fee_type_enum,
    p_amount       NUMERIC,
    p_as_of        DATE DEFAULT CURRENT_DATE,
    p_holding_days INTEGER DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
    v_formula_id UUID;
    v_rate       NUMERIC;
BEGIN
    SELECT formula_id INTO v_formula_id
      FROM product_fee_formula
     WHERE fee_type = p_fee_type
       AND (product_id = p_product_id OR product_id IS NULL)
       AND effective_date <= p_as_of
       AND (expiry_date IS NULL OR expiry_date >= p_as_of)
     ORDER BY product_id NULLS LAST, effective_date DESC
     LIMIT 1;

    IF v_formula_id IS NULL THEN
        RAISE EXCEPTION 'calculate_product_fee: no product_fee_formula assignment for product %, fee_type % as of %',
            p_product_id, p_fee_type, p_as_of;
    END IF;

    v_rate := get_fee_rate(v_formula_id, p_amount, p_holding_days);
    RETURN ROUND(p_amount * v_rate, 2);
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- calculate_agent_fee_sharing: resolve the applicable agent_fee_formula
-- assignment for (agent, product) as of a given date, then apply its
-- rate to a base amount (typically the product fee just collected, or
-- the gross transaction amount per the agreement terms).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_agent_fee_sharing(
    p_agent_id     UUID,
    p_product_id   UUID,
    p_base_amount  NUMERIC,
    p_as_of        DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC AS $$
DECLARE
    v_formula_id UUID;
    v_rate       NUMERIC;
BEGIN
    SELECT formula_id INTO v_formula_id
      FROM agent_fee_formula
     WHERE agent_id = p_agent_id
       AND product_id = p_product_id
       AND effective_date <= p_as_of
       AND (expiry_date IS NULL OR expiry_date >= p_as_of)
     ORDER BY effective_date DESC
     LIMIT 1;

    IF v_formula_id IS NULL THEN
        RAISE EXCEPTION 'calculate_agent_fee_sharing: no agent_fee_formula assignment for agent %, product % as of %',
            p_agent_id, p_product_id, p_as_of;
    END IF;

    v_rate := get_fee_rate(v_formula_id, p_base_amount, NULL);
    RETURN ROUND(p_base_amount * v_rate, 2);
END;
$$ LANGUAGE plpgsql;
