-- ============================================================
-- 08_cash_settlement.sql — Domain 4
-- PAYMENT_INSTRUCTION, BANK_STATEMENT_LINE, PAYMENT_MATCHING,
-- SETTLEMENT_INSTRUCTION, SINVEST_MESSAGE, KSEI_CONFIRMATION
-- ============================================================

CREATE TABLE payment_instruction (
    instruction_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id         UUID NOT NULL REFERENCES order_txn(order_id),
    bank_id          UUID NOT NULL REFERENCES custodian_bank(bank_id),
    amount           NUMERIC(18,2) NOT NULL CHECK (amount >= 0),
    instruction_type instruction_type_enum NOT NULL
);
CREATE INDEX idx_payment_instruction_order ON payment_instruction(order_id);
CREATE INDEX idx_payment_instruction_bank ON payment_instruction(bank_id);

CREATE TABLE bank_statement_line (
    line_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id    UUID NOT NULL REFERENCES custodian_bank(bank_id),
    value_date DATE NOT NULL,
    amount     NUMERIC(18,2) NOT NULL,
    reference  VARCHAR(100)
);
CREATE INDEX idx_bank_statement_line_bank_date ON bank_statement_line(bank_id, value_date);

CREATE TABLE payment_matching (
    matching_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instruction_id    UUID NOT NULL REFERENCES payment_instruction(instruction_id),
    statement_line_id UUID NOT NULL REFERENCES bank_statement_line(line_id),
    status            matching_status_enum NOT NULL DEFAULT 'UNMATCHED',
    UNIQUE (instruction_id, statement_line_id)
);
CREATE INDEX idx_payment_matching_status ON payment_matching(status);

CREATE TABLE settlement_instruction (
    settlement_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES order_txn(order_id),
    settlement_date DATE NOT NULL,
    sla_status      sla_status_enum NOT NULL DEFAULT 'ON_TRACK'
);
CREATE INDEX idx_settlement_instruction_order ON settlement_instruction(order_id);
CREATE INDEX idx_settlement_instruction_sla ON settlement_instruction(sla_status);

CREATE TABLE sinvest_message (
    message_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID NOT NULL REFERENCES order_txn(order_id),
    direction    message_direction_enum NOT NULL,
    message_type VARCHAR(40) NOT NULL,
    sent_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sinvest_message_order ON sinvest_message(order_id);

CREATE TABLE ksei_confirmation (
    confirmation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES order_txn(order_id),
    units           NUMERIC(18,4) NOT NULL,
    confirmed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ksei_confirmation_order ON ksei_confirmation(order_id);
