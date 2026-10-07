-- ============================================================
-- 09_reporting_governance.sql — Domain 5 (part 1, pre-existing)
-- INVESTOR_STATEMENT, REPORT_DEFINITION, REPORT_EXECUTION_LOG
-- ============================================================

CREATE TABLE investor_statement (
    statement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cif          VARCHAR(20) NOT NULL REFERENCES customer(cif),
    period       VARCHAR(10) NOT NULL,   -- e.g. '2026-09'
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    file_ref     TEXT
);
CREATE INDEX idx_investor_statement_cif_period ON investor_statement(cif, period);

CREATE TABLE report_definition (
    report_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_code     VARCHAR(10) NOT NULL UNIQUE,
    category        report_category_enum NOT NULL,
    report_name     VARCHAR(150) NOT NULL,
    description     TEXT,
    source_entities JSONB NOT NULL DEFAULT '[]',
    filter_schema   JSONB NOT NULL DEFAULT '{}',
    export_formats  export_format_enum[] NOT NULL DEFAULT ARRAY['CSV','PDF']::export_format_enum[],
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_report_definition_category ON report_definition(category);

CREATE TABLE report_execution_log (
    execution_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id        UUID NOT NULL REFERENCES report_definition(report_id),
    user_id          UUID REFERENCES user_account(user_id),  -- NULL if triggered by scheduler
    filter_params    JSONB NOT NULL DEFAULT '{}',
    execution_mode   execution_mode_enum NOT NULL DEFAULT 'MANUAL',
    export_format    VARCHAR(10),
    delivery_channel report_delivery_channel_enum,
    status           execution_status_enum NOT NULL DEFAULT 'SUCCESS',
    row_count        INTEGER NOT NULL DEFAULT 0,
    executed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_report_execution_log_report ON report_execution_log(report_id);
CREATE INDEX idx_report_execution_log_user ON report_execution_log(user_id);
CREATE INDEX idx_report_execution_log_executed_at ON report_execution_log(executed_at);
