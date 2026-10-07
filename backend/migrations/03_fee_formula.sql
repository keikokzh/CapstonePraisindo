-- ============================================================
-- 03_fee_formula.sql — Fee Formula module (Domain 1 & 2)
-- FEE_FORMULA, FEE_FORMULA_TIER, PRODUCT_FEE_FORMULA here;
-- AGENT_FEE_FORMULA is created in 05_sales_distribution.sql
-- (it references selling_agent, created there).
-- Design: separate the FORMULA ("what") from the ASSIGNMENT
-- ("who/when") so one formula can be applied to many products/agreements.
-- ============================================================

CREATE TABLE fee_formula (
    formula_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    formula_code  VARCHAR(40) NOT NULL UNIQUE,
    scope         fee_scope_enum NOT NULL,
    fee_type      fee_type_enum,            -- required if scope=PRODUCT_FEE, NULL if FEE_SHARING
    pricing_model pricing_model_enum NOT NULL,
    calc_method   calc_method_enum NOT NULL DEFAULT 'FLAT',
    flat_rate     NUMERIC(7,4),             -- used when pricing_model = FLAT
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fee_formula_scope_type CHECK (
        (scope = 'PRODUCT_FEE' AND fee_type IS NOT NULL) OR
        (scope = 'FEE_SHARING' AND fee_type IS NULL)
    ),
    CONSTRAINT chk_fee_formula_flat_rate CHECK (
        (pricing_model = 'FLAT' AND flat_rate IS NOT NULL) OR
        (pricing_model <> 'FLAT')
    )
);
CREATE INDEX idx_fee_formula_scope ON fee_formula(scope, fee_type);

CREATE TABLE fee_formula_tier (
    tier_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    formula_id UUID NOT NULL REFERENCES fee_formula(formula_id) ON DELETE CASCADE,
    tier_from  NUMERIC(18,2) NOT NULL,
    tier_to    NUMERIC(18,2),              -- NULL = unbounded (top band)
    rate       NUMERIC(7,4) NOT NULL,
    CONSTRAINT chk_fee_formula_tier_range CHECK (tier_to IS NULL OR tier_to > tier_from)
);
CREATE INDEX idx_fee_formula_tier_formula ON fee_formula_tier(formula_id, tier_from);

CREATE TABLE product_fee_formula (
    assignment_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id     UUID REFERENCES product(product_id),   -- NULL = Global default
    fee_type       fee_type_enum NOT NULL,
    formula_id     UUID NOT NULL REFERENCES fee_formula(formula_id),
    effective_date DATE NOT NULL,
    expiry_date    DATE,
    CONSTRAINT chk_product_fee_formula_dates CHECK (expiry_date IS NULL OR expiry_date >= effective_date)
);
CREATE INDEX idx_product_fee_formula_lookup ON product_fee_formula(product_id, fee_type, effective_date DESC);

-- Enforce that an assigned formula's scope (and fee_type, for products) matches.
CREATE OR REPLACE FUNCTION check_product_fee_formula() RETURNS TRIGGER AS $$
DECLARE
    f_scope fee_scope_enum;
    f_type  fee_type_enum;
BEGIN
    SELECT scope, fee_type INTO f_scope, f_type FROM fee_formula WHERE formula_id = NEW.formula_id;
    IF f_scope <> 'PRODUCT_FEE' THEN
        RAISE EXCEPTION 'product_fee_formula.formula_id must reference a PRODUCT_FEE-scope fee_formula (got %)', f_scope;
    END IF;
    IF f_type <> NEW.fee_type THEN
        RAISE EXCEPTION 'product_fee_formula.fee_type (%) does not match fee_formula.fee_type (%)', NEW.fee_type, f_type;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_product_fee_formula
    BEFORE INSERT OR UPDATE ON product_fee_formula
    FOR EACH ROW EXECUTE FUNCTION check_product_fee_formula();
