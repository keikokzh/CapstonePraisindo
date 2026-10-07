-- ============================================================
-- 06_transactions.sql — Domain 3 (part 1)
-- ORDER_TXN, SWITCHING_DETAIL, TRANSFER_DETAIL,
-- DISTRIBUTION_EVENT, DISTRIBUTION_PAYMENT
-- (order_txn.netting_batch_id FK is added in 07_netting.sql,
--  deferred because netting_batch references order_txn's product_id
--  pattern but not order_txn itself — see 07 for the ALTER)
-- ============================================================

CREATE TABLE order_txn (
    order_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_date    DATE NOT NULL,
    order_date       TIMESTAMPTZ NOT NULL DEFAULT now(),
    product_id       UUID NOT NULL REFERENCES product(product_id),
    cif              VARCHAR(20) NOT NULL REFERENCES customer(cif),
    agent_id         UUID REFERENCES selling_agent(agent_id),
    order_type       order_type_enum NOT NULL,
    gross_amount     NUMERIC(18,2) NOT NULL CHECK (gross_amount >= 0),
    fee_amount       NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    stamp_duty       NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (stamp_duty >= 0),
    net_amount       NUMERIC(18,2) NOT NULL,
    units            NUMERIC(18,4) NOT NULL CHECK (units >= 0),
    lifecycle_status lifecycle_status_enum NOT NULL DEFAULT 'PENDING_FUND',
    netting_batch_id UUID  -- FK added in 07_netting.sql
);
CREATE INDEX idx_order_txn_business_date ON order_txn(business_date);
CREATE INDEX idx_order_txn_product ON order_txn(product_id);
CREATE INDEX idx_order_txn_cif ON order_txn(cif);
CREATE INDEX idx_order_txn_agent ON order_txn(agent_id);
CREATE INDEX idx_order_txn_type_status ON order_txn(order_type, lifecycle_status);

CREATE TABLE switching_detail (
    order_id          UUID PRIMARY KEY REFERENCES order_txn(order_id),
    source_product_id UUID NOT NULL REFERENCES product(product_id),
    target_product_id UUID NOT NULL REFERENCES product(product_id),
    CONSTRAINT chk_switching_different_products CHECK (source_product_id <> target_product_id)
);

CREATE TABLE transfer_detail (
    order_id        UUID PRIMARY KEY REFERENCES order_txn(order_id),
    from_cif        VARCHAR(20) NOT NULL REFERENCES customer(cif),
    to_cif          VARCHAR(20) NOT NULL REFERENCES customer(cif),
    transfer_type   transfer_type_enum NOT NULL,
    document_status transfer_doc_status_enum NOT NULL DEFAULT 'PENDING',
    CONSTRAINT chk_transfer_different_parties CHECK (from_cif <> to_cif)
);

CREATE TABLE distribution_event (
    event_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id       UUID NOT NULL REFERENCES product(product_id),
    declaration_date DATE NOT NULL,
    payment_date     DATE NOT NULL,
    rate_per_unit    NUMERIC(18,6) NOT NULL CHECK (rate_per_unit >= 0),
    CONSTRAINT chk_distribution_event_dates CHECK (payment_date >= declaration_date)
);
CREATE INDEX idx_distribution_event_product ON distribution_event(product_id);
CREATE INDEX idx_distribution_event_payment_date ON distribution_event(payment_date);

CREATE TABLE distribution_payment (
    payment_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        UUID NOT NULL REFERENCES distribution_event(event_id),
    cif             VARCHAR(20) NOT NULL REFERENCES customer(cif),
    gross_dividend  NUMERIC(18,2) NOT NULL CHECK (gross_dividend >= 0),
    method          distribution_method_enum NOT NULL,
    net_cash        NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (net_cash >= 0),
    units_purchased NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (units_purchased >= 0)
);
CREATE INDEX idx_distribution_payment_event ON distribution_payment(event_id);
CREATE INDEX idx_distribution_payment_cif ON distribution_payment(cif);
