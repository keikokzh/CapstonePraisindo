-- ============================================================
-- 02_master_data.sql — Domain 1 (minus Fee Formula, see 03)
-- CUSTODIAN_BANK, PRODUCT, PRODUCT_NAV, SYSTEM_PARAMETER
-- ============================================================

CREATE TABLE custodian_bank (
    bank_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name  VARCHAR(150) NOT NULL,
    swift_code VARCHAR(11),
    status     bank_status_enum NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE product (
    product_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_code     VARCHAR(20) NOT NULL UNIQUE,
    product_name     VARCHAR(150) NOT NULL,
    product_type     product_type_enum NOT NULL,
    status           product_status_enum NOT NULL DEFAULT 'DRAFT',
    custodian_bank_id UUID REFERENCES custodian_bank(bank_id),
    isin_code        VARCHAR(20),
    inception_date   DATE,
    currency         CHAR(3) NOT NULL DEFAULT 'IDR'
);
CREATE INDEX idx_product_custodian ON product(custodian_bank_id);
CREATE INDEX idx_product_status ON product(status);

CREATE TABLE product_nav (
    nav_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id       UUID NOT NULL REFERENCES product(product_id),
    nav_date         DATE NOT NULL,
    nav_per_unit     NUMERIC(18,4) NOT NULL CHECK (nav_per_unit >= 0),
    units_outstanding NUMERIC(18,4) NOT NULL CHECK (units_outstanding >= 0),
    aum              NUMERIC(18,2) NOT NULL CHECK (aum >= 0),
    UNIQUE (product_id, nav_date)
);
CREATE INDEX idx_product_nav_date ON product_nav(nav_date);

CREATE TABLE system_parameter (
    param_key   VARCHAR(100) PRIMARY KEY,
    param_value TEXT NOT NULL,
    description TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
