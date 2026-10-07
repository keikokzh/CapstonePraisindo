-- ============================================================
-- 13_sample_data.sql — Sample / demo data
-- Tujuan: mengisi SEMUA 37 tabel dengan data yang saling terhubung
-- secara realistis, sehingga ke-25 laporan pada report_definition
-- (katalog TRX/CIF/PRD/SET/SLS/CPL) bisa dijalankan dan menampilkan
-- hasil yang masuk akal — bukan hanya skema kosong.
--
-- Berbeda dari 12_seed_data.sql (role/user/katalog laporan/whitelist
-- — data REFERENSI yang memang harus selalu ada) — file ini murni
-- data CONTOH/DEMO dan AMAN dihapus/di-reset kapan saja tanpa
-- memengaruhi fungsi sistem. Jalankan setelah 00-12.
--
-- order_txn.fee_amount sengaja dihitung dengan rate FLAT yang
-- berlaku umum (mis. Redemption EQ01 tetap dicatat 1%, bukan hasil
-- resolve DSC RED-PEF-DSC-3YR yang baru di-assign khusus untuk EQ01
-- di bagian Fee Formula bawah) — ini KONSISTEN dengan BR-RPT-08 di
-- FSD Modul Reporting: fee pada laporan transaksi adalah snapshot
-- historis saat transaksi terjadi, bukan hasil hitung ulang dengan
-- formula yang berlaku saat ini.
-- ============================================================

-- ---------------------------------------------------------------
-- 1) Master Data: Custodian Bank, Product, NAV history (PRD-01/02/03)
-- ---------------------------------------------------------------
INSERT INTO custodian_bank (bank_id, bank_name, swift_code) VALUES
    ('a0000000-0000-0000-0000-00000000b001', 'Bank Kustodian Nusantara', 'BKNIIDJA'),
    ('a0000000-0000-0000-0000-00000000b002', 'Bank Kustodian Sentosa',   'BKSIIDJA');

INSERT INTO product (product_id, product_code, product_name, product_type, status, custodian_bank_id, isin_code, inception_date) VALUES
    ('a0000000-0000-0000-0000-00000000d001', 'EQ01', 'Praisindo Equity Fund',       'EQUITY',       'ACTIVE', 'a0000000-0000-0000-0000-00000000b001', 'IDN000312345', '2019-03-01'),
    ('a0000000-0000-0000-0000-00000000d002', 'FI01', 'Praisindo Fixed Income Fund', 'FIXED_INCOME', 'ACTIVE', 'a0000000-0000-0000-0000-00000000b001', 'IDN000312346', '2018-07-15'),
    ('a0000000-0000-0000-0000-00000000d003', 'MM01', 'Praisindo Money Market Fund', 'MONEY_MARKET', 'ACTIVE', 'a0000000-0000-0000-0000-00000000b002', 'IDN000312347', '2017-01-10'),
    ('a0000000-0000-0000-0000-00000000d004', 'BL01', 'Praisindo Balanced Fund',     'BALANCED',     'ACTIVE', 'a0000000-0000-0000-0000-00000000b001', 'IDN000312348', '2020-11-20'),
    ('a0000000-0000-0000-0000-00000000d005', 'ET01', 'Praisindo Gold ETF',          'ETF',          'DRAFT',  'a0000000-0000-0000-0000-00000000b002', NULL,           NULL);

-- 30 hari histori NAV untuk 4 produk ACTIVE (naik perlahan + oscillasi kecil)
INSERT INTO product_nav (product_id, nav_date, nav_per_unit, units_outstanding, aum)
SELECT p.product_id,
       (CURRENT_DATE - gs.d)::date AS nav_date,
       ROUND((b.base_nav * (1 + 0.0008 * (29 - gs.d)) + 3 * sin(29 - gs.d))::numeric, 4) AS nav_per_unit,
       (b.base_units + (29 - gs.d) * 1200)::numeric AS units_outstanding,
       ROUND(((b.base_nav * (1 + 0.0008 * (29 - gs.d)) + 3 * sin(29 - gs.d))
              * (b.base_units + (29 - gs.d) * 1200))::numeric, 2) AS aum
FROM (VALUES
    ('EQ01', 1450.00, 850000),
    ('FI01', 1120.00, 1200000),
    ('MM01', 1008.50, 2100000),
    ('BL01', 1265.00, 640000)
) AS b(product_code, base_nav, base_units)
JOIN product p ON p.product_code = b.product_code
CROSS JOIN generate_series(0, 29) AS gs(d);

-- ---------------------------------------------------------------
-- 2) Fee Formula catalog + assignments (PRD-04)
-- ---------------------------------------------------------------
INSERT INTO fee_formula (formula_id, formula_code, scope, fee_type, pricing_model, calc_method, flat_rate) VALUES
    ('a0000000-0000-0000-0000-00000000f001', 'SUBS-FLAT-1.5PCT',  'PRODUCT_FEE', 'SUBSCRIPTION', 'FLAT',   'FLAT', 0.0150),
    ('a0000000-0000-0000-0000-00000000f002', 'SWTC-FLAT-0.5PCT',  'PRODUCT_FEE', 'SWITCHING',    'FLAT',   'FLAT', 0.0050),
    ('a0000000-0000-0000-0000-00000000f003', 'MGMT-FLAT-2PCT',    'PRODUCT_FEE', 'MANAGEMENT',   'FLAT',   'FLAT', 0.0200),
    ('a0000000-0000-0000-0000-00000000f004', 'CUST-FLAT-0.25PCT', 'PRODUCT_FEE', 'CUSTODIAN',    'FLAT',   'FLAT', 0.0025),
    ('a0000000-0000-0000-0000-00000000f005', 'TAX-FLAT-10PCT',    'PRODUCT_FEE', 'TAX',          'FLAT',   'FLAT', 0.1000),
    ('a0000000-0000-0000-0000-00000000f006', 'RED-FLAT-1PCT',     'PRODUCT_FEE', 'REDEMPTION',   'FLAT',   'FLAT', 0.0100),
    ('a0000000-0000-0000-0000-00000000f007', 'RED-PEF-DSC-3YR',   'PRODUCT_FEE', 'REDEMPTION',   'TIERED', 'DSC',  NULL),
    ('a0000000-0000-0000-0000-00000000f008', 'SHARING-FLAT-30PCT','FEE_SHARING', NULL,           'FLAT',   'FLAT', 0.3000),
    ('a0000000-0000-0000-0000-00000000f009', 'SHARING-TIERED-AUM','FEE_SHARING', NULL,           'TIERED_PROGRESSIVE','FLAT', NULL);

INSERT INTO fee_formula_tier (formula_id, tier_from, tier_to, rate) VALUES
    ('a0000000-0000-0000-0000-00000000f007', 0,    365,  0.0300),
    ('a0000000-0000-0000-0000-00000000f007', 365,  730,  0.0200),
    ('a0000000-0000-0000-0000-00000000f007', 730,  1095, 0.0100),
    ('a0000000-0000-0000-0000-00000000f007', 1095, NULL, 0.0000),
    ('a0000000-0000-0000-0000-00000000f009', 0,    50000000000, 0.2000),
    ('a0000000-0000-0000-0000-00000000f009', 50000000000, NULL, 0.3000);

-- Global defaults (product_id NULL) + 1 override (EQ01 Redemption -> DSC)
INSERT INTO product_fee_formula (product_id, fee_type, formula_id, effective_date) VALUES
    (NULL, 'SUBSCRIPTION', 'a0000000-0000-0000-0000-00000000f001', '2024-01-01'),
    (NULL, 'SWITCHING',    'a0000000-0000-0000-0000-00000000f002', '2024-01-01'),
    (NULL, 'MANAGEMENT',   'a0000000-0000-0000-0000-00000000f003', '2024-01-01'),
    (NULL, 'CUSTODIAN',    'a0000000-0000-0000-0000-00000000f004', '2024-01-01'),
    (NULL, 'TAX',          'a0000000-0000-0000-0000-00000000f005', '2024-01-01'),
    (NULL, 'REDEMPTION',   'a0000000-0000-0000-0000-00000000f006', '2024-01-01'),
    ('a0000000-0000-0000-0000-00000000d001', 'REDEMPTION', 'a0000000-0000-0000-0000-00000000f007', '2024-01-01');

-- ---------------------------------------------------------------
-- 3) Sales & Distribution (SLS-01..04)
-- ---------------------------------------------------------------
INSERT INTO selling_agent (agent_id, agent_code, agent_name, region, license_no, status) VALUES
    ('a0000000-0000-0000-0000-00000000a001', 'AG01', 'PT Mitra Investama Sejahtera', 'DKI Jakarta', 'APERD-001', 'ACTIVE'),
    ('a0000000-0000-0000-0000-00000000a002', 'AG02', 'Bank Mitra Prima',             'Jawa Barat',  'APERD-002', 'ACTIVE'),
    ('a0000000-0000-0000-0000-00000000a003', 'AG03', 'IFA Nusantara Wealth',         'Jawa Timur',  'APERD-003', 'ACTIVE');

INSERT INTO distribution_network (agent_id, channel_type, parent_group) VALUES
    ('a0000000-0000-0000-0000-00000000a001', 'IFA',  'Mitra Investama Group'),
    ('a0000000-0000-0000-0000-00000000a002', 'BANK', 'Bank Mitra Prima Group'),
    ('a0000000-0000-0000-0000-00000000a003', 'IFA',  'Nusantara Wealth Group');

INSERT INTO sales_person (agent_id, name, role) VALUES
    ('a0000000-0000-0000-0000-00000000a001', 'Dewi Anggraini',  'Relationship Manager'),
    ('a0000000-0000-0000-0000-00000000a001', 'Farah Amelia',    'Sales Executive'),
    ('a0000000-0000-0000-0000-00000000a002', 'Galih Prasetyo',  'Relationship Manager'),
    ('a0000000-0000-0000-0000-00000000a003', 'Hendra Wijaya',   'Independent Advisor');

INSERT INTO commission_schedule (agent_id, product_id, rate, effective_date, payment_status) VALUES
    ('a0000000-0000-0000-0000-00000000a001', 'a0000000-0000-0000-0000-00000000d001', 0.0050, '2024-01-01', 'PAID'),
    ('a0000000-0000-0000-0000-00000000a002', 'a0000000-0000-0000-0000-00000000d002', 0.0030, '2024-01-01', 'PENDING'),
    ('a0000000-0000-0000-0000-00000000a003', 'a0000000-0000-0000-0000-00000000d003', 0.0015, '2024-01-01', 'PAID');

INSERT INTO agent_fee_formula (agent_id, product_id, formula_id, effective_date) VALUES
    ('a0000000-0000-0000-0000-00000000a001', 'a0000000-0000-0000-0000-00000000d001', 'a0000000-0000-0000-0000-00000000f008', '2024-01-01'),
    ('a0000000-0000-0000-0000-00000000a002', 'a0000000-0000-0000-0000-00000000d002', 'a0000000-0000-0000-0000-00000000f009', '2024-01-01');

-- ---------------------------------------------------------------
-- 4) Customer Registry (CIF-01/02)
-- ---------------------------------------------------------------
INSERT INTO customer (cif, customer_name, customer_type, kyc_status, agent_id, marital_status, investment_purpose) VALUES
    ('CIF0000001', 'Andi Wijaya',        'INDIVIDUAL', 'VERIFIED', 'a0000000-0000-0000-0000-00000000a001', 'MARRIED',  'Dana Pensiun'),
    ('CIF0000002', 'Siti Rahma',         'INDIVIDUAL', 'VERIFIED', 'a0000000-0000-0000-0000-00000000a002', 'SINGLE',   'Pendidikan Anak'),
    ('CIF0000003', 'Budi Santoso',       'INDIVIDUAL', 'VERIFIED', 'a0000000-0000-0000-0000-00000000a001', 'MARRIED',  'Investasi Jangka Panjang'),
    ('CIF0000004', 'PT Nusantara Abadi', 'CORPORATE',  'VERIFIED', 'a0000000-0000-0000-0000-00000000a003', NULL,       'Treasury Management'),
    ('CIF0000005', 'Dimas Prakoso',      'INDIVIDUAL', 'PENDING',  'a0000000-0000-0000-0000-00000000a002', 'SINGLE',   'Dana Darurat'),
    ('CIF0000006', 'Rina Kusuma',        'INDIVIDUAL', 'REJECTED', 'a0000000-0000-0000-0000-00000000a003', 'DIVORCED', 'Investasi Jangka Pendek');

INSERT INTO customer_document (cif, document_type, file_ref, status) VALUES
    ('CIF0000001', 'KTP',            'docs/ktp-andi.pdf',      'VERIFIED'),
    ('CIF0000001', 'NPWP',           'docs/npwp-andi.pdf',     'VERIFIED'),
    ('CIF0000002', 'KTP',            'docs/ktp-siti.pdf',      'VERIFIED'),
    ('CIF0000003', 'KTP',            'docs/ktp-budi.pdf',      'UNDER_REVIEW'),
    ('CIF0000004', 'Akta Pendirian', 'docs/akta-nusantara.pdf','VERIFIED'),
    ('CIF0000005', 'KTP',            'docs/ktp-dimas.pdf',     'RECEIVED'),
    ('CIF0000006', 'KTP',            'docs/ktp-rina.pdf',      'RECEIVED');

INSERT INTO investor_account (cif, product_id, sid, ifua, status) VALUES
    ('CIF0000001', 'a0000000-0000-0000-0000-00000000d001', 'SID00000001', 'IFUA0000001EQ01', 'ACTIVE'),
    ('CIF0000001', 'a0000000-0000-0000-0000-00000000d004', 'SID00000001', 'IFUA0000001BL01', 'ACTIVE'),
    ('CIF0000002', 'a0000000-0000-0000-0000-00000000d003', 'SID00000002', 'IFUA0000002MM01', 'ACTIVE'),
    ('CIF0000003', 'a0000000-0000-0000-0000-00000000d001', 'SID00000003', 'IFUA0000003EQ01', 'ACTIVE'),
    ('CIF0000003', 'a0000000-0000-0000-0000-00000000d002', 'SID00000003', 'IFUA0000003FI01', 'DORMANT'),
    ('CIF0000004', 'a0000000-0000-0000-0000-00000000d002', 'SID00000004', 'IFUA0000004FI01', 'ACTIVE'),
    ('CIF0000005', 'a0000000-0000-0000-0000-00000000d003', 'SID00000005', 'IFUA0000005MM01', 'ACTIVE');

-- ---------------------------------------------------------------
-- 5) Netting batches (TRX-06)
-- ---------------------------------------------------------------
INSERT INTO netting_batch (netting_id, business_date, product_id, netting_status, total_buy, total_sell, net_order_qty) VALUES
    ('a0000000-0000-0000-0000-00000000cc01', CURRENT_DATE - 1, 'a0000000-0000-0000-0000-00000000d001', 'SENT_TO_SINVEST', 500000000, 50000000,  146601.35),
    ('a0000000-0000-0000-0000-00000000cc02', CURRENT_DATE - 1, 'a0000000-0000-0000-0000-00000000d002', 'NETTED',          492500000, 99000000,  343455.50);

-- ---------------------------------------------------------------
-- 6) Order Transactions (TRX-01..08) — 22 orders, all 4 order_type,
--    all 6 lifecycle_status, across all 4 ACTIVE products
-- ---------------------------------------------------------------
INSERT INTO order_txn (order_id, business_date, order_date, product_id, cif, agent_id, order_type, gross_amount, fee_amount, net_amount, units, lifecycle_status, netting_batch_id) VALUES
    ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE,      CURRENT_DATE + interval '9 hours',  'a0000000-0000-0000-0000-00000000d001', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'SUBSCRIPTION', 100000000, 1500000, 98500000,  66554.0541, 'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000002', CURRENT_DATE - 1,  CURRENT_DATE - 1 + interval '9 hours','a0000000-0000-0000-0000-00000000d001', 'CIF0000003', 'a0000000-0000-0000-0000-00000000a001', 'SUBSCRIPTION', 250000000, 3750000, 246250000, 166385.1351, 'SETTLED',          'a0000000-0000-0000-0000-00000000cc01'),
    ('a0000000-0000-0000-0000-000000000003', CURRENT_DATE - 1,  CURRENT_DATE - 1 + interval '10 hours','a0000000-0000-0000-0000-00000000d001', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'REDEMPTION',   50000000,  500000,  49500000,  33783.7838, 'SETTLED',          'a0000000-0000-0000-0000-00000000cc01'),
    ('a0000000-0000-0000-0000-000000000004', CURRENT_DATE - 2,  CURRENT_DATE - 2 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d001', 'CIF0000003', 'a0000000-0000-0000-0000-00000000a001', 'SWITCHING',    80000000,  400000,  79600000,  54054.0541, 'SETTLED',          NULL),
    ('a0000000-0000-0000-0000-000000000005', CURRENT_DATE - 3,  CURRENT_DATE - 3 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d004', 'CIF0000001', NULL,                                    'TRANSFER',     30000000,  0,       30000000,  23183.9000, 'SETTLED',          NULL),
    ('a0000000-0000-0000-0000-000000000006', CURRENT_DATE - 1,  CURRENT_DATE - 1 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d002', 'CIF0000004', 'a0000000-0000-0000-0000-00000000a003', 'SUBSCRIPTION', 500000000, 7500000, 492500000, 429842.9319, 'SETTLED',          'a0000000-0000-0000-0000-00000000cc02'),
    ('a0000000-0000-0000-0000-000000000007', CURRENT_DATE - 1,  CURRENT_DATE - 1 + interval '10 hours','a0000000-0000-0000-0000-00000000d002', 'CIF0000004', 'a0000000-0000-0000-0000-00000000a003', 'REDEMPTION',   100000000, 1000000, 99000000,  86387.4346, 'SETTLED',          'a0000000-0000-0000-0000-00000000cc02'),
    ('a0000000-0000-0000-0000-000000000008', CURRENT_DATE,      CURRENT_DATE + interval '9 hours',  'a0000000-0000-0000-0000-00000000d003', 'CIF0000002', 'a0000000-0000-0000-0000-00000000a002', 'SUBSCRIPTION', 20000000,  300000,  19700000,  19089.1473, 'PENDING_SETTLEMENT', NULL),
    ('a0000000-0000-0000-0000-000000000009', CURRENT_DATE,      CURRENT_DATE + interval '9 hours',  'a0000000-0000-0000-0000-00000000d003', 'CIF0000005', 'a0000000-0000-0000-0000-00000000a002', 'SUBSCRIPTION', 5000000,   75000,   4925000,   4772.2868,  'PENDING_FUND',       NULL),
    ('a0000000-0000-0000-0000-000000000010', CURRENT_DATE - 4,  CURRENT_DATE - 4 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d002', 'CIF0000003', 'a0000000-0000-0000-0000-00000000a001', 'SWITCHING',    40000000,  200000,  39800000,  34729.5000, 'PENDING_NAV',        NULL),
    ('a0000000-0000-0000-0000-000000000011', CURRENT_DATE - 5,  CURRENT_DATE - 5 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d001', 'CIF0000003', 'a0000000-0000-0000-0000-00000000a001', 'REDEMPTION',   15000000,  150000,  14850000,  10033.7838, 'EXCEPTION',          NULL),
    ('a0000000-0000-0000-0000-000000000012', CURRENT_DATE - 6,  CURRENT_DATE - 6 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d004', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'SUBSCRIPTION', 60000000,  900000,  59100000,  45672.3000, 'CLOSED',             NULL),
    ('a0000000-0000-0000-0000-000000000013', CURRENT_DATE - 2,  CURRENT_DATE - 2 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d003', 'CIF0000005', 'a0000000-0000-0000-0000-00000000a002', 'REDEMPTION',   3000000,   30000,   2970000,   2878.5000,  'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000014', CURRENT_DATE - 7,  CURRENT_DATE - 7 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d001', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'SUBSCRIPTION', 200000000, 3000000, 197000000, 133108.1000, 'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000015', CURRENT_DATE - 8,  CURRENT_DATE - 8 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d002', 'CIF0000004', 'a0000000-0000-0000-0000-00000000a003', 'SWITCHING',    70000000,  350000,  69650000,  60776.6000, 'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000016', CURRENT_DATE - 9,  CURRENT_DATE - 9 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d003', 'CIF0000002', NULL,                                    'TRANSFER',     10000000,  0,       10000000,  9689.9000,  'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000017', CURRENT_DATE - 10, CURRENT_DATE - 10 + interval '9 hours', 'a0000000-0000-0000-0000-00000000d001', 'CIF0000003', 'a0000000-0000-0000-0000-00000000a001', 'SUBSCRIPTION', 90000000,  1350000, 88650000,  59898.6000, 'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000018', CURRENT_DATE - 3,  CURRENT_DATE - 3 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d002', 'CIF0000004', 'a0000000-0000-0000-0000-00000000a003', 'REDEMPTION',   25000000,  250000,  24750000,  21598.6000, 'EXCEPTION',          NULL),
    ('a0000000-0000-0000-0000-000000000019', CURRENT_DATE - 4,  CURRENT_DATE - 4 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d004', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'REDEMPTION',   10000000,  100000,  9900000,   7651.1000,  'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000020', CURRENT_DATE - 1,  CURRENT_DATE - 1 + interval '9 hours',  'a0000000-0000-0000-0000-00000000d003', 'CIF0000005', 'a0000000-0000-0000-0000-00000000a002', 'SUBSCRIPTION', 2000000,   30000,   1970000,   1908.9000,  'PENDING_FUND',       NULL),
    ('a0000000-0000-0000-0000-000000000021', CURRENT_DATE - 11, CURRENT_DATE - 11 + interval '9 hours', 'a0000000-0000-0000-0000-00000000d001', 'CIF0000001', 'a0000000-0000-0000-0000-00000000a001', 'SWITCHING',    120000000, 600000,  119400000, 80675.7000, 'SETTLED',           NULL),
    ('a0000000-0000-0000-0000-000000000022', CURRENT_DATE - 12, CURRENT_DATE - 12 + interval '9 hours', 'a0000000-0000-0000-0000-00000000d002', 'CIF0000004', 'a0000000-0000-0000-0000-00000000a003', 'SUBSCRIPTION', 1000000000,15000000,985000000, 859616.1000,'SETTLED',           NULL);

INSERT INTO switching_detail (order_id, source_product_id, target_product_id) VALUES
    ('a0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-00000000d001', 'a0000000-0000-0000-0000-00000000d004'), -- EQ01 -> BL01
    ('a0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-00000000d002', 'a0000000-0000-0000-0000-00000000d003'), -- FI01 -> MM01
    ('a0000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-00000000d002', 'a0000000-0000-0000-0000-00000000d004'), -- FI01 -> BL01
    ('a0000000-0000-0000-0000-000000000021', 'a0000000-0000-0000-0000-00000000d001', 'a0000000-0000-0000-0000-00000000d002'); -- EQ01 -> FI01

INSERT INTO transfer_detail (order_id, from_cif, to_cif, transfer_type, document_status) VALUES
    ('a0000000-0000-0000-0000-000000000005', 'CIF0000001', 'CIF0000003', 'GIFT',        'LENGKAP'),
    ('a0000000-0000-0000-0000-000000000016', 'CIF0000002', 'CIF0000005', 'INHERITANCE', 'LENGKAP');

-- ---------------------------------------------------------------
-- 7) Distribution / Dividend events (TRX-05)
-- ---------------------------------------------------------------
INSERT INTO distribution_event (event_id, product_id, declaration_date, payment_date, rate_per_unit) VALUES
    ('a0000000-0000-0000-0000-00000000e001', 'a0000000-0000-0000-0000-00000000d001', CURRENT_DATE - 20, CURRENT_DATE - 13, 12.50),
    ('a0000000-0000-0000-0000-00000000e002', 'a0000000-0000-0000-0000-00000000d004', CURRENT_DATE - 15, CURRENT_DATE - 8,  8.75);

INSERT INTO distribution_payment (event_id, cif, gross_dividend, method, net_cash, units_purchased) VALUES
    ('a0000000-0000-0000-0000-00000000e001', 'CIF0000001', 831925.68,   'CASH',     748733.11, 0),
    ('a0000000-0000-0000-0000-00000000e001', 'CIF0000003', 2079814.19,  'REINVEST', 0,          1264.7500),
    ('a0000000-0000-0000-0000-00000000e002', 'CIF0000001', 399632.63,   'CASH',     359669.36, 0);

-- ---------------------------------------------------------------
-- 8) Cash, NAV & Settlement (SET-01/02, CPL-03) — 8 representative
--    SETTLED orders get the full payment/settlement/S-INVEST chain
-- ---------------------------------------------------------------
INSERT INTO payment_instruction (order_id, bank_id, amount, instruction_type)
SELECT o.order_id, p.custodian_bank_id, o.net_amount,
       CASE WHEN o.order_type = 'SUBSCRIPTION' THEN 'DEBIT' ELSE 'CREDIT' END::instruction_type_enum
FROM order_txn o JOIN product p ON p.product_id = o.product_id
WHERE o.order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

INSERT INTO bank_statement_line (bank_id, value_date, amount, reference)
SELECT pi.bank_id, o.business_date, pi.amount, 'REF-' || substr(o.order_id::text, 1, 8)
FROM payment_instruction pi JOIN order_txn o ON o.order_id = pi.order_id
WHERE o.order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

-- 2 dari 8 sengaja ditandai UNMATCHED untuk menunjukkan variasi status
INSERT INTO payment_matching (instruction_id, statement_line_id, status)
SELECT pi.instruction_id, bsl.line_id,
       CASE WHEN o.order_id IN ('a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000022')
            THEN 'UNMATCHED' ELSE 'MATCHED' END::matching_status_enum
FROM payment_instruction pi
JOIN order_txn o ON o.order_id = pi.order_id
JOIN bank_statement_line bsl ON bsl.bank_id = pi.bank_id AND bsl.amount = pi.amount AND bsl.value_date = o.business_date
WHERE o.order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

INSERT INTO settlement_instruction (order_id, settlement_date, sla_status)
SELECT order_id, business_date + 1,
       CASE WHEN order_id = 'a0000000-0000-0000-0000-000000000007' THEN 'BREACH'
            WHEN order_id = 'a0000000-0000-0000-0000-000000000022' THEN 'AT_RISK'
            ELSE 'ON_TRACK' END::sla_status_enum
FROM order_txn
WHERE order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

INSERT INTO sinvest_message (order_id, direction, message_type, sent_at)
SELECT order_id, 'OUTBOUND'::message_direction_enum, 'ORDER_SUBMISSION', business_date::timestamptz + interval '9 hours'
FROM order_txn
WHERE order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
)
UNION ALL
SELECT order_id, 'INBOUND'::message_direction_enum, 'ORDER_CONFIRMATION', business_date::timestamptz + interval '15 hours'
FROM order_txn
WHERE order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

INSERT INTO ksei_confirmation (order_id, units, confirmed_at)
SELECT order_id, units, business_date::timestamptz + interval '16 hours'
FROM order_txn
WHERE order_id IN (
    'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000014',
    'a0000000-0000-0000-0000-000000000017','a0000000-0000-0000-0000-000000000022'
);

-- ---------------------------------------------------------------
-- 9) Compliance & Governance (CPL-01..05)
-- ---------------------------------------------------------------
INSERT INTO aml_screening_flag (order_id, indication_type, investigation_status, resolved_at, resolved_by) VALUES
    ('a0000000-0000-0000-0000-000000000011', 'UNUSUAL_PATTERN',       'UNDER_INVESTIGATION', NULL, NULL),
    ('a0000000-0000-0000-0000-000000000018', 'STRUCTURING',           'NEW',                  NULL, NULL),
    ('a0000000-0000-0000-0000-000000000003', 'LARGE_CASH_TRANSACTION','RESOLVED', now() - interval '2 days', '10000000-0000-0000-0000-000000000002');

INSERT INTO investor_statement (cif, period, file_ref) VALUES
    ('CIF0000001', '2026-09', 'statements/CIF0000001-2026-09.pdf'),
    ('CIF0000001', '2026-08', 'statements/CIF0000001-2026-08.pdf'),
    ('CIF0000003', '2026-09', 'statements/CIF0000003-2026-09.pdf'),
    ('CIF0000004', '2026-09', 'statements/CIF0000004-2026-09.pdf');

INSERT INTO report_delivery_schedule (schedule_id, report_id, cron_expression, export_format, delivery_channel, recipient_list, status, created_by, approved_by, approved_at) VALUES
    ('a0000000-0000-0000-0000-00000000dd01',
     (SELECT report_id FROM report_definition WHERE report_code = 'CPL-04'),
     '0 7 1 * *', 'PDF', 'EMAIL', '["direksi@praisindo.com","compliance@praisindo.com"]', 'ACTIVE',
     '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', now() - interval '10 days'),
    ('a0000000-0000-0000-0000-00000000dd02',
     (SELECT report_id FROM report_definition WHERE report_code = 'PRD-03'),
     '0 6 * * 1', 'XLSX', 'WHATSAPP', '["+6281234567890"]', 'PENDING_APPROVAL',
     '10000000-0000-0000-0000-000000000001', NULL, NULL);

INSERT INTO adhoc_report_query (owner_user_id, name, description, entity, columns, filters, is_shared) VALUES
    ('10000000-0000-0000-0000-000000000003', 'Top AUM per Agent 30 Hari',
     'Query ad-hoc untuk melihat nilai transaksi tertinggi per selling agent dalam 30 hari terakhir',
     'order_txn', '["order_id","business_date","gross_amount","cif"]', '{"business_date":{"gte":"-30d"}}', TRUE);

INSERT INTO report_execution_log (report_id, user_id, filter_params, execution_mode, export_format, delivery_channel, status, row_count, executed_at) VALUES
    ((SELECT report_id FROM report_definition WHERE report_code = 'TRX-01'), '10000000-0000-0000-0000-000000000001', '{"business_date":"2026-10-05"}', 'MANUAL',    'PDF',  'SCREEN', 'SUCCESS', 8,   now() - interval '2 days'),
    ((SELECT report_id FROM report_definition WHERE report_code = 'PRD-02'), '10000000-0000-0000-0000-000000000003', '{}',                             'MANUAL',    'CSV',  'SCREEN', 'SUCCESS', 120, now() - interval '1 days'),
    ((SELECT report_id FROM report_definition WHERE report_code = 'CPL-04'), NULL,                                    '{}',                             'SCHEDULED', 'PDF',  'EMAIL',  'SUCCESS', 36,  now() - interval '10 days'),
    ((SELECT report_id FROM report_definition WHERE report_code = 'SLS-04'), '10000000-0000-0000-0000-000000000003', '{"period":"2026-09"}',          'MANUAL',    'XLSX', 'SCREEN', 'FAILED',  0,   now() - interval '5 days');

INSERT INTO audit_trail (user_id, entity_name, entity_id, action_code, old_value, new_value) VALUES
    ('10000000-0000-0000-0000-000000000001', 'order_txn',               'a0000000-0000-0000-0000-000000000011', 'X', '{"lifecycle_status":"PENDING_SETTLEMENT"}', '{"lifecycle_status":"EXCEPTION"}'),
    ('10000000-0000-0000-0000-000000000002', 'report_delivery_schedule','a0000000-0000-0000-0000-00000000dd01', 'A', '{"status":"PENDING_APPROVAL"}',             '{"status":"ACTIVE"}'),
    ('10000000-0000-0000-0000-000000000003', 'customer',                'CIF0000006',                            'R', NULL,                                          NULL);
