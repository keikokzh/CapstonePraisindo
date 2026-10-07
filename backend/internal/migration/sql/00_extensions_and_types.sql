-- ============================================================
-- Praisindo IMS 2026 URS — PostgreSQL Schema v2.0
-- 00_extensions_and_types.sql
-- Extensions and ENUM types shared across all domains.
-- Source: Praisindo_IMS2026_URS_DataModel_v2.docx (37 entities, 5 domains)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()

-- ---------- Domain 1: Master Data & Produk ----------
CREATE TYPE product_type_enum AS ENUM ('EQUITY','FIXED_INCOME','MONEY_MARKET','BALANCED','ETF','OTHER');
CREATE TYPE product_status_enum AS ENUM ('ACTIVE','DRAFT','INACTIVE');
CREATE TYPE bank_status_enum AS ENUM ('ACTIVE','INACTIVE');
CREATE TYPE fee_scope_enum AS ENUM ('PRODUCT_FEE','FEE_SHARING');
CREATE TYPE fee_type_enum AS ENUM ('SUBSCRIPTION','REDEMPTION','SWITCHING','MANAGEMENT','CUSTODIAN','TAX');
CREATE TYPE pricing_model_enum AS ENUM ('FLAT','TIERED','TIERED_PROGRESSIVE');
CREATE TYPE calc_method_enum AS ENUM ('FLAT','DSC','FIFO');

-- ---------- Domain 2: Registri Nasabah & Penjualan ----------
CREATE TYPE customer_type_enum AS ENUM ('INDIVIDUAL','CORPORATE');
CREATE TYPE kyc_status_enum AS ENUM ('PENDING','VERIFIED','REJECTED');
CREATE TYPE marital_status_enum AS ENUM ('SINGLE','MARRIED','DIVORCED','WIDOWED');
CREATE TYPE investor_account_status_enum AS ENUM ('ACTIVE','DORMANT');
CREATE TYPE doc_review_status_enum AS ENUM ('VERIFIED','UNDER_REVIEW','RECEIVED');
CREATE TYPE agent_status_enum AS ENUM ('ACTIVE','INACTIVE');
CREATE TYPE channel_type_enum AS ENUM ('BANK','ONLINE','IFA','INSTITUTIONAL','OTHER');
CREATE TYPE commission_payment_status_enum AS ENUM ('PENDING','PAID','CANCELLED');

-- ---------- Domain 3: Manajemen Transaksi ----------
CREATE TYPE order_type_enum AS ENUM ('SUBSCRIPTION','REDEMPTION','SWITCHING','TRANSFER');
CREATE TYPE lifecycle_status_enum AS ENUM ('PENDING_FUND','PENDING_NAV','PENDING_SETTLEMENT','SETTLED','EXCEPTION','CLOSED');
CREATE TYPE transfer_type_enum AS ENUM ('INHERITANCE','GIFT','OTHER');
CREATE TYPE transfer_doc_status_enum AS ENUM ('LENGKAP','PENDING','DITOLAK');
CREATE TYPE distribution_method_enum AS ENUM ('CASH','REINVEST');
CREATE TYPE netting_status_enum AS ENUM ('OPEN','NETTED','SENT_TO_SINVEST');

-- ---------- Domain 4: Kas, NAV, Settlement & Eksternal ----------
CREATE TYPE instruction_type_enum AS ENUM ('DEBIT','CREDIT');
CREATE TYPE matching_status_enum AS ENUM ('MATCHED','UNMATCHED');
CREATE TYPE sla_status_enum AS ENUM ('ON_TRACK','AT_RISK','BREACH');
CREATE TYPE message_direction_enum AS ENUM ('OUTBOUND','INBOUND');

-- ---------- Domain 5: Statement, Report & Governance ----------
CREATE TYPE user_status_enum AS ENUM ('ACTIVE','INACTIVE');
CREATE TYPE audit_action_enum AS ENUM ('C','R','E','A','X','M'); -- Create/Read/Edit/Approve/eXport/Maker-checker submit
CREATE TYPE report_category_enum AS ENUM ('TRX','CIF','PRD','SET','SLS','CPL');
CREATE TYPE export_format_enum AS ENUM ('CSV','PDF','XLSX');
CREATE TYPE execution_mode_enum AS ENUM ('MANUAL','SCHEDULED');
CREATE TYPE report_delivery_channel_enum AS ENUM ('SCREEN','EMAIL','WHATSAPP');
CREATE TYPE execution_status_enum AS ENUM ('SUCCESS','FAILED','RETRYING');
CREATE TYPE schedule_status_enum AS ENUM ('PENDING_APPROVAL','ACTIVE','FAILED','DISABLED');
CREATE TYPE schedule_delivery_channel_enum AS ENUM ('EMAIL','WHATSAPP','BOTH');
CREATE TYPE aml_investigation_status_enum AS ENUM ('NEW','UNDER_INVESTIGATION','RESOLVED','REPORTED_TO_PPATK');
