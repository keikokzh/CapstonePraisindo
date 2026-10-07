-- ============================================================
-- 12_seed_data.sql
-- 1) 25-report catalog -> report_definition
--    (names/categories per claude/urs2026-report-briefing-deck.md,
--    the project's source of truth for the 25-report list)
-- 2) a starter adhoc_entity_whitelist for the Ad-hoc Query tool
-- 3) minimal role/user_account rows so FK-bearing seed/test data
--    (report_execution_log, report_delivery_schedule) has
--    something real to reference during validation
-- ============================================================

-- ---- 1) Roles & a seed user (Maker + Checker for governance testing) ----
INSERT INTO role (role_id, role_name, description) VALUES
    ('00000000-0000-0000-0000-000000000001', 'REPORT_MAKER',  'Membuat/menjadwalkan laporan (Maker)'),
    ('00000000-0000-0000-0000-000000000002', 'REPORT_CHECKER','Menyetujui jadwal laporan (Checker)'),
    ('00000000-0000-0000-0000-000000000003', 'SYSTEM_ADMIN',  'Administrator sistem / konfigurasi master');

INSERT INTO user_account (user_id, name, email, role_id, status) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Seed Maker',   'seed.maker@praisindo.com',   '00000000-0000-0000-0000-000000000001', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000002', 'Seed Checker', 'seed.checker@praisindo.com', '00000000-0000-0000-0000-000000000002', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000003', 'Seed Admin',   'seed.admin@praisindo.com',   '00000000-0000-0000-0000-000000000003', 'ACTIVE');

-- ---- 2) 25-report catalog ----
INSERT INTO report_definition (report_code, category, report_name, description, source_entities, export_formats) VALUES
('TRX-01', 'TRX', 'Subscription per Produk',                               'Rincian transaksi subscription per produk/periode.',                       '["order_txn","product","customer"]',                                               ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-02', 'TRX', 'Redemption per Produk',                                 'Rincian transaksi redemption per produk/periode.',                          '["order_txn","product","customer"]',                                               ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-03', 'TRX', 'Switching per Produk',                                 'Rincian transaksi switching antar produk.',                                 '["order_txn","switching_detail","product","customer"]',                            ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-04', 'TRX', 'Asset/Unit Transfer per Produk',                       'Rincian transfer unit/aset antar nasabah.',                                 '["order_txn","transfer_detail","product","customer"]',                             ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-05', 'TRX', 'Distribution/Dividend Payment',                        'Rincian pembayaran distribusi/dividen per event.',                          '["distribution_event","distribution_payment","product","customer"]',               ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-06', 'TRX', 'Netting Transaction Report',                           'Rekap batch netting harian per produk (buy/sell/net qty).',                '["netting_batch","order_txn","product"]',                                          ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-07', 'TRX', 'Transaction Blotter Summary',                          'Ringkasan seluruh jenis transaksi dalam satu tampilan blotter.',           '["order_txn","product","customer","selling_agent"]',                               ARRAY['CSV','PDF']::export_format_enum[]),
('TRX-08', 'TRX', 'Exception/Rejected Transaction',                       'Transaksi dengan lifecycle_status EXCEPTION atau ditolak.',                '["order_txn"]',                                                                    ARRAY['CSV','PDF']::export_format_enum[]),
('CIF-01', 'CIF', 'Customer Registration Report',                         'Daftar registrasi nasabah baru per periode/status KYC.',                   '["customer"]',                                                                      ARRAY['CSV','PDF']::export_format_enum[]),
('CIF-02', 'CIF', 'Investor Account (SID/IFUA) Report',                   'Daftar rekening investor per produk (SID/IFUA).',                          '["investor_account","customer","product"]',                                        ARRAY['CSV','PDF']::export_format_enum[]),
('PRD-01', 'PRD', 'Product Master Report',                                'Daftar master produk aktif/non-aktif.',                                    '["product","custodian_bank"]',                                                     ARRAY['CSV','PDF']::export_format_enum[]),
('PRD-02', 'PRD', 'NAV History Report',                                   'Riwayat NAV per unit per produk per tanggal.',                             '["product_nav","product"]',                                                        ARRAY['CSV','PDF','XLSX']::export_format_enum[]),
('PRD-03', 'PRD', 'AUM Summary Report',                                   'Ringkasan AUM per produk/tanggal.',                                        '["product_nav","product"]',                                                        ARRAY['CSV','PDF']::export_format_enum[]),
('PRD-04', 'PRD', 'Fee Formula Assignment Report',                        'Daftar assignment formula fee aktif per produk.',                          '["product_fee_formula","fee_formula","product"]',                                  ARRAY['CSV','PDF']::export_format_enum[]),
('SET-01', 'SET', 'Payment Matching Report',                              'Status pencocokan instruksi pembayaran vs. rekening koran.',              '["payment_matching","payment_instruction","bank_statement_line"]',                 ARRAY['CSV','PDF']::export_format_enum[]),
('SET-02', 'SET', 'Settlement Monitor Report',                            'Status SLA settlement per order (ON_TRACK/AT_RISK/BREACH).',              '["settlement_instruction","order_txn"]',                                           ARRAY['CSV','PDF']::export_format_enum[]),
('SLS-01', 'SLS', 'Sales Distribution Report',                            'Rincian penjualan per jaringan distribusi/agent.',                         '["order_txn","distribution_network","selling_agent"]',                             ARRAY['CSV','PDF']::export_format_enum[]),
('SLS-02', 'SLS', 'Commission Report',                                    'Rincian komisi agen per produk/periode.',                                  '["commission_schedule","selling_agent","product"]',                                ARRAY['CSV','PDF']::export_format_enum[]),
('SLS-03', 'SLS', 'Selling Agent Performance Report',                     'Kinerja agent (AUM tertarik, jumlah transaksi) per periode.',             '["order_txn","product_nav","selling_agent"]',                                      ARRAY['CSV','PDF']::export_format_enum[]),
('SLS-04', 'SLS', 'Management Fee Sharing per Produk per Selling Agent',  'Fee sharing harian per produk per agent (resolver calculate_agent_fee_sharing).', '["agent_fee_formula","fee_formula","product_nav","selling_agent","product"]', ARRAY['CSV','PDF','XLSX']::export_format_enum[]),
('CPL-01', 'CPL', 'POJK Compliance Summary Report',                       'Ringkasan kepatuhan POJK (ilustratif, lihat catatan FSD).',                '["product_nav","order_txn"]',                                                      ARRAY['CSV','PDF']::export_format_enum[]),
('CPL-02', 'CPL', 'AML/PPATK Suspicious Transaction',                     'Daftar transaksi yang ditandai AML_SCREENING_FLAG.',                       '["aml_screening_flag","order_txn","customer"]',                                    ARRAY['CSV','PDF']::export_format_enum[]),
('CPL-03', 'CPL', 'S-INVEST Reconciliation Report',                       'Rekonsiliasi pesan S-INVEST vs. konfirmasi KSEI.',                         '["sinvest_message","ksei_confirmation","order_txn"]',                              ARRAY['CSV','PDF']::export_format_enum[]),
('CPL-04', 'CPL', 'Maker-Checker Audit Report',                           'Jejak audit aksi Maker/Checker lintas modul.',                             '["audit_trail","user_account"]',                                                   ARRAY['CSV','PDF']::export_format_enum[]),
('CPL-05', 'CPL', 'Regulatory Reporting Submission Log',                  'Log eksekusi/pengiriman laporan regulasi.',                                '["report_execution_log","report_definition"]',                                     ARRAY['CSV','PDF']::export_format_enum[]);

-- ---- 3) Ad-hoc Entity Whitelist (BR-RPT-14/15 governance) ----
-- Starter set: a few low-risk, frequently-requested entities. Expanding
-- this list is a governance action (ADHOC_ENTITY_WHITELIST row insert),
-- not a code change — by design (mirrors FEE_FORMULA catalog pattern).
INSERT INTO adhoc_entity_whitelist (entity_name, allowed_columns, allowed_roles) VALUES
    ('order_txn', '["order_id","business_date","product_id","cif","order_type","gross_amount","net_amount","units","lifecycle_status"]', '["REPORT_MAKER","REPORT_CHECKER","SYSTEM_ADMIN"]'),
    ('customer',  '["cif","customer_name","customer_type","kyc_status","registered_at"]',                                                 '["REPORT_MAKER","REPORT_CHECKER","SYSTEM_ADMIN"]'),
    ('product',   '["product_id","product_code","product_name","product_type","status"]',                                               '["REPORT_MAKER","REPORT_CHECKER","SYSTEM_ADMIN"]'),
    ('product_nav','["product_id","nav_date","nav_per_unit","aum"]',                                                                      '["REPORT_MAKER","REPORT_CHECKER","SYSTEM_ADMIN"]');
