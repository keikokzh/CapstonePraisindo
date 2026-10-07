-- Seed: Deterministic dummy data for TRX-01 demo
-- Uses synthetic data only — no real customer information.
-- Matches the mockup's data patterns: 3 funds, 8 customers, 4 channels, multiple statuses.
--
-- Stamp duty rule (ASUMSI DEMO — belum dikonfirmasi final):
--   Rp10.000 jika gross_amount > Rp10.000.000, sesuai deskripsi Data Model v2.
--
-- Net amount = gross_amount - fee_amount - stamp_duty
-- Units tersimpan di DB (bukan dihitung ulang), sesuai Data Model v2.

-- Safe for re-seeding without deleting existing data
-- ============================================================
-- PRODUCTS (from mockup: 3 funds)
-- ============================================================
INSERT INTO product (product_code, product_name, product_type, isin_code, inception_date) VALUES
('PEF',  'Praisindo Equity Fund',       'Equity',       'ID0EQF000001', '2020-01-15'),
('PFIF', 'Praisindo Fixed Income Fund',  'Fixed Income', 'ID0FIF000002', '2019-06-01'),
('PMMF', 'Praisindo Money Market Fund',  'Money Market', 'ID0MMF000003', '2021-03-10')
ON CONFLICT (product_code) DO NOTHING;

-- ============================================================
-- PRODUCT NAV (daily NAV for August 2026)
-- ============================================================
INSERT INTO product_nav (product_id, nav_date, nav_per_unit, units_outstanding, aum)
SELECT
    p.product_id,
    d::date,
    CASE p.product_code
        WHEN 'PEF'  THEN 1842.55 + (EXTRACT(DOY FROM d::date) * 0.31)
        WHEN 'PFIF' THEN 1215.30 + (EXTRACT(DOY FROM d::date) * 0.12)
        WHEN 'PMMF' THEN 1102.10 + (EXTRACT(DOY FROM d::date) * 0.05)
    END,
    1000000,
    CASE p.product_code
        WHEN 'PEF'  THEN 1842550000
        WHEN 'PFIF' THEN 1215300000
        WHEN 'PMMF' THEN 1102100000
    END
FROM product p
CROSS JOIN generate_series('2026-08-01'::date, '2026-08-31'::date, '1 day'::interval) d
ON CONFLICT (product_id, nav_date) DO NOTHING;

-- ============================================================
-- CUSTOMERS (from mockup: 8 synthetic customers)
-- ============================================================
INSERT INTO customer (cif, customer_name, customer_type) VALUES
('9001-882', 'Andi Wijaya',      'Individu'),
('9002-104', 'Siti Rahmawati',   'Individu'),
('9003-771', 'Budi Santoso',     'Individu'),
('9004-330', 'Maria Kusuma',     'Individu'),
('9005-556', 'Hendra Gunawan',   'Individu'),
('9006-219', 'Dewi Lestari',     'Individu'),
('9007-845', 'Fajar Nugroho',    'Individu'),
('9008-063', 'Ratna Puspita',    'Individu')
ON CONFLICT (cif) DO NOTHING;

-- ============================================================
-- SELLING AGENTS (4 agents, one per channel type)
-- ============================================================
INSERT INTO selling_agent (agent_code, agent_name, region, license_no) VALUES
('AGT-001', 'Kantor Cabang Jakarta',       'DKI Jakarta',  'APERD-001'),
('AGT-002', 'Bank Distributor Mandiri',     'Nasional',     'APERD-002'),
('AGT-003', 'Sekuritas Indo Premier',       'DKI Jakarta',  'APERD-003'),
('AGT-004', 'Digital Channel Praisindo',    'Online',       'APERD-004')
ON CONFLICT (agent_code) DO NOTHING;

-- ============================================================
-- DISTRIBUTION NETWORK (4 channels matching mockup)
-- ============================================================
INSERT INTO distribution_network (agent_id, channel_type, parent_group)
SELECT * FROM (VALUES
    (1, 'Direct — Kantor Cabang',      'Praisindo Internal'),
    (2, 'APERD — Bank Distributor',    'Mandiri Group'),
    (3, 'APERD — Sekuritas',           'Indo Premier'),
    (4, 'Digital/Online Channel',      'Praisindo Digital')
) AS v(agent_id, channel_type, parent_group)
WHERE NOT EXISTS (
    SELECT 1 FROM distribution_network
);

-- ============================================================
-- INVESTOR ACCOUNTS (SID per customer per product)
-- ============================================================
INSERT INTO investor_account (cif, product_id, sid, ifua)
SELECT c.cif, p.product_id,
    'IDSID000' || REPLACE(c.cif, '-', ''),
    'IFUA000' || REPLACE(c.cif, '-', '') || p.product_code
FROM customer c
CROSS JOIN product p
ON CONFLICT (sid, product_id) DO NOTHING;

-- ============================================================
-- ORDER TRANSACTIONS (85 deterministic subscription orders)
-- Spread across August 2026, various statuses, all 3 products, 4 channels
-- ============================================================

-- Helper: generate deterministic transactions
-- Net = Gross - Fee - StampDuty
-- StampDuty = 10000 if Gross > 10000000, else 0 (ASUMSI DEMO)
-- Units = Net / NAV (pre-computed, stored as snapshot)
-- Fee = Gross * rate (0.5%-1.5% depending on product, snapshot)

DO $$
DECLARE
    v_cifs TEXT[] := ARRAY['9001-882','9002-104','9003-771','9004-330','9005-556','9006-219','9007-845','9008-063'];
    v_products INTEGER[] := ARRAY[1,2,3];
    v_agents INTEGER[] := ARRAY[1,2,3,4];
    v_statuses TEXT[] := ARRAY['SETTLED','SETTLED','SETTLED','PENDING_SETTLEMENT','PENDING_NAV','EXCEPTION'];
    v_base_amounts NUMERIC[] := ARRAY[25000000, 50000000, 100000000, 150000000, 200000000, 75000000, 35000000, 300000000, 450000000, 15000000];
    v_nav_bases NUMERIC[] := ARRAY[1917.46, 1244.06, 1114.25]; -- Approx NAV mid-Aug
    v_fee_rates NUMERIC[] := ARRAY[0.01, 0.0075, 0.005]; -- 1% equity, 0.75% FI, 0.5% MM

    v_cif TEXT;
    v_product INTEGER;
    v_agent INTEGER;
    v_status TEXT;
    v_day INTEGER;
    v_gross NUMERIC;
    v_fee NUMERIC;
    v_stamp NUMERIC;
    v_net NUMERIC;
    v_nav NUMERIC;
    v_units NUMERIC;
    v_bdate DATE;
    v_sdate DATE;
    v_txn_code TEXT;
    v_counter INTEGER := 0;
    v_seed INTEGER;
BEGIN
    FOR i IN 1..85 LOOP
        -- Deterministic selections based on loop index
        v_seed := (i * 7 + 13) % 100;
        v_cif := v_cifs[(i % 8) + 1];
        v_product := v_products[(i % 3) + 1];
        v_agent := v_agents[(i % 4) + 1];
        v_status := v_statuses[((i * 3) % 6) + 1];
        v_day := (i % 31) + 1;
        v_bdate := ('2026-08-01'::date + ((v_day - 1) || ' days')::interval)::date;

        -- Deterministic gross amount
        v_gross := v_base_amounts[((i * 11) % 10) + 1] + (v_seed * 100000);

        -- Fee based on product type (snapshot, per BR-RPT-08)
        v_fee := ROUND(v_gross * v_fee_rates[v_product], 2);

        -- Stamp duty (ASUMSI DEMO): Rp10.000 if gross > Rp10.000.000
        v_stamp := CASE WHEN v_gross > 10000000 THEN 10000 ELSE 0 END;

        -- Net = Gross - Fee - StampDuty
        v_net := v_gross - v_fee - v_stamp;

        -- NAV snapshot (slight daily variation)
        v_nav := v_nav_bases[v_product] + (v_day * 0.15);

        -- Units = Net / NAV (pre-computed)
        v_units := ROUND(v_net / v_nav, 4);

        -- Settlement date (only for SETTLED, T+2 or T+3)
        v_sdate := CASE
            WHEN v_status = 'SETTLED' THEN v_bdate + ((2 + (i % 2)) || ' days')::interval
            ELSE NULL
        END;

        -- Transaction code
        v_counter := v_counter + 1;
        v_txn_code := 'SUB2608' || LPAD(v_day::text, 2, '0') || '-' || LPAD(v_counter::text, 4, '0');

        INSERT INTO order_txn (
            transaction_code, business_date, product_id, cif, agent_id,
            order_type, gross_amount, fee_amount, stamp_duty, net_amount,
            units, nav_per_unit, lifecycle_status, settlement_date
        ) VALUES (
            v_txn_code, v_bdate, v_product, v_cif, v_agent,
            'SUBSCRIPTION', v_gross, v_fee, v_stamp, v_net,
            v_units, v_nav, v_status, v_sdate
        ) ON CONFLICT (transaction_code) DO NOTHING;
    END LOOP;
END $$;
