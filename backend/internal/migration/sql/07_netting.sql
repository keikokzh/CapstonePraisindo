-- ============================================================
-- 07_netting.sql — NETTING_BATCH [ENTITAS BARU]
-- Closes the gap flagged in Praisindo_IMS2026_FSD_ReportingModule_v1.docx
-- (TRX-06 Netting Transaction Report referenced order_txn.netting_status,
-- which had no basis in the schema). Modeled as a relational entity
-- (not a single status column) since a netting batch is a daily
-- per-product process with its own attributes.
-- ============================================================

CREATE TABLE netting_batch (
    netting_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_date  DATE NOT NULL,
    product_id     UUID NOT NULL REFERENCES product(product_id),
    netting_status netting_status_enum NOT NULL DEFAULT 'OPEN',
    total_buy      NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (total_buy >= 0),
    total_sell     NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (total_sell >= 0),
    net_order_qty  NUMERIC(18,4) NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (business_date, product_id)
);
CREATE INDEX idx_netting_batch_date_product ON netting_batch(business_date, product_id);

ALTER TABLE order_txn
    ADD CONSTRAINT fk_order_txn_netting_batch FOREIGN KEY (netting_batch_id) REFERENCES netting_batch(netting_id);
CREATE INDEX idx_order_txn_netting_batch ON order_txn(netting_batch_id);
