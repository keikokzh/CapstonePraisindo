-- Migration: Create tables for TRX-01 Subscription per Produk Report
-- Aligned with Praisindo IMS 2026 Data Model v2
-- Safe to run repeatedly (IF NOT EXISTS)

-- Domain 1: Master Data & Produk
CREATE TABLE IF NOT EXISTS product (
    product_id   SERIAL PRIMARY KEY,
    product_code VARCHAR(20) UNIQUE NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    product_type VARCHAR(30) NOT NULL,  -- Equity/Fixed Income/Money Market/Balanced
    status       VARCHAR(20) DEFAULT 'Active',
    isin_code    VARCHAR(20),
    inception_date DATE,
    currency     CHAR(3) DEFAULT 'IDR'
);

CREATE TABLE IF NOT EXISTS product_nav (
    nav_id           SERIAL PRIMARY KEY,
    product_id       INTEGER REFERENCES product(product_id),
    nav_date         DATE NOT NULL,
    nav_per_unit     NUMERIC(18,4) NOT NULL,
    units_outstanding NUMERIC(18,4),
    aum              NUMERIC(18,2),
    UNIQUE(product_id, nav_date)
);

-- Domain 2: Registri Nasabah & Penjualan
CREATE TABLE IF NOT EXISTS customer (
    customer_id   SERIAL PRIMARY KEY,
    cif           VARCHAR(20) UNIQUE NOT NULL,
    customer_name VARCHAR(150) NOT NULL,
    customer_type VARCHAR(20) DEFAULT 'Individu',
    kyc_status    VARCHAR(20) DEFAULT 'Verified',
    registered_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS selling_agent (
    agent_id   SERIAL PRIMARY KEY,
    agent_code VARCHAR(20) UNIQUE NOT NULL,
    agent_name VARCHAR(150) NOT NULL,
    region     VARCHAR(60),
    license_no VARCHAR(40),
    status     VARCHAR(20) DEFAULT 'Active'
);

CREATE TABLE IF NOT EXISTS distribution_network (
    network_id   SERIAL PRIMARY KEY,
    agent_id     INTEGER REFERENCES selling_agent(agent_id),
    channel_type VARCHAR(60) NOT NULL,
    parent_group VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS investor_account (
    account_id  SERIAL PRIMARY KEY,
    cif         VARCHAR(20) REFERENCES customer(cif),
    product_id  INTEGER REFERENCES product(product_id),
    sid         VARCHAR(30) NOT NULL,
    ifua        VARCHAR(30),
    status      VARCHAR(20) DEFAULT 'Active',
    UNIQUE(sid, product_id)
);

-- Domain 3: Manajemen Transaksi (hanya ORDER_TXN untuk TRX-01)
CREATE TABLE IF NOT EXISTS order_txn (
    order_id         SERIAL PRIMARY KEY,
    transaction_code VARCHAR(30) UNIQUE NOT NULL,
    business_date    DATE NOT NULL,
    order_date       TIMESTAMPTZ DEFAULT NOW(),
    product_id       INTEGER REFERENCES product(product_id),
    cif              VARCHAR(20) REFERENCES customer(cif),
    agent_id         INTEGER REFERENCES selling_agent(agent_id),
    order_type       VARCHAR(20) NOT NULL,  -- SUBSCRIPTION/REDEMPTION/SWITCHING/TRANSFER
    gross_amount     NUMERIC(18,2) NOT NULL,
    fee_amount       NUMERIC(18,2) NOT NULL DEFAULT 0,
    stamp_duty       NUMERIC(10,2) NOT NULL DEFAULT 0,
    net_amount       NUMERIC(18,2) NOT NULL,
    units            NUMERIC(18,4) NOT NULL,
    nav_per_unit     NUMERIC(18,4) NOT NULL,
    lifecycle_status VARCHAR(30) NOT NULL DEFAULT 'PENDING_NAV',
    settlement_date  DATE
);

-- Indexes for TRX-01 query performance
CREATE INDEX IF NOT EXISTS idx_order_txn_type_date ON order_txn(order_type, business_date);
CREATE INDEX IF NOT EXISTS idx_order_txn_status ON order_txn(lifecycle_status);
CREATE INDEX IF NOT EXISTS idx_order_txn_product ON order_txn(product_id);
CREATE INDEX IF NOT EXISTS idx_order_txn_cif ON order_txn(cif);
