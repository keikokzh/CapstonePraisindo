-- ============================================================
-- 04_customer_registry.sql — Domain 2 (part 1)
-- CUSTOMER, INVESTOR_ACCOUNT, CUSTOMER_DOCUMENT
-- (SELLING_AGENT is referenced by CUSTOMER.agent_id but created
--  in 05_sales_distribution.sql — FK added via ALTER at the end
--  of 05 to avoid a forward-reference ordering problem)
-- ============================================================

CREATE TABLE customer (
    cif                VARCHAR(20) PRIMARY KEY,
    customer_name      VARCHAR(150) NOT NULL,
    customer_type      customer_type_enum NOT NULL,
    kyc_status         kyc_status_enum NOT NULL DEFAULT 'PENDING',
    registered_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    agent_id           UUID,  -- FK added in 05_sales_distribution.sql
    marital_status     marital_status_enum,
    investment_purpose VARCHAR(100)
);
CREATE INDEX idx_customer_kyc_status ON customer(kyc_status);

CREATE TABLE investor_account (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cif        VARCHAR(20) NOT NULL REFERENCES customer(cif),
    product_id UUID NOT NULL REFERENCES product(product_id),
    sid        VARCHAR(30) NOT NULL,
    ifua       VARCHAR(30) NOT NULL,
    status     investor_account_status_enum NOT NULL DEFAULT 'ACTIVE',
    UNIQUE (sid, product_id)
);
CREATE INDEX idx_investor_account_cif ON investor_account(cif);
CREATE INDEX idx_investor_account_product ON investor_account(product_id);

CREATE TABLE customer_document (
    document_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cif           VARCHAR(20) NOT NULL REFERENCES customer(cif),
    document_type VARCHAR(60) NOT NULL,
    file_ref      TEXT,
    status        doc_review_status_enum NOT NULL DEFAULT 'RECEIVED',
    uploaded_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_customer_document_cif ON customer_document(cif);
