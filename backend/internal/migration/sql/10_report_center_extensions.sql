-- ============================================================
-- 10_report_center_extensions.sql — Domain 5 (part 2)
-- 4 ENTITAS BARU yang menutup gap di
-- Praisindo_IMS2026_FSD_ReportingModule_v1.docx:
--   REPORT_DELIVERY_SCHEDULE  (FR-RPT-035/036, BR-RPT-12 Maker<>Checker)
--   ADHOC_REPORT_QUERY        (FR-RPT-034)
--   ADHOC_ENTITY_WHITELIST    (FR-RPT-033, BR-RPT-14/15)
--   AML_SCREENING_FLAG        (CPL-02, menggantikan placeholder JSONB)
-- ============================================================

CREATE TABLE report_delivery_schedule (
    schedule_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id         UUID NOT NULL REFERENCES report_definition(report_id),
    cron_expression   VARCHAR(40) NOT NULL,
    export_format     VARCHAR(10) NOT NULL,
    delivery_channel  schedule_delivery_channel_enum NOT NULL,
    recipient_list    JSONB NOT NULL DEFAULT '[]',
    status            schedule_status_enum NOT NULL DEFAULT 'PENDING_APPROVAL',
    created_by        UUID NOT NULL REFERENCES user_account(user_id),
    approved_by       UUID REFERENCES user_account(user_id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_at       TIMESTAMPTZ,
    CONSTRAINT chk_report_delivery_schedule_approval
        CHECK (approved_by IS NULL OR approved_by <> created_by)
);
CREATE INDEX idx_report_delivery_schedule_report ON report_delivery_schedule(report_id);
CREATE INDEX idx_report_delivery_schedule_status ON report_delivery_schedule(status);

-- BR-RPT-12: "Checker tidak boleh sama dengan Maker pada jadwal distribusi
-- yang sama" — trigger enforces this on activation (status -> ACTIVE),
-- not just at insert time, in case approved_by is set after creation.
CREATE OR REPLACE FUNCTION check_report_delivery_schedule_maker_checker() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'ACTIVE' AND NEW.approved_by IS NOT NULL AND NEW.approved_by = NEW.created_by THEN
        RAISE EXCEPTION 'report_delivery_schedule: approved_by (Checker) must differ from created_by (Maker) — BR-RPT-12';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_report_delivery_schedule_maker_checker
    BEFORE INSERT OR UPDATE ON report_delivery_schedule
    FOR EACH ROW EXECUTE FUNCTION check_report_delivery_schedule_maker_checker();

CREATE TABLE adhoc_report_query (
    query_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES user_account(user_id),
    name          VARCHAR(150) NOT NULL,
    description   TEXT,
    entity        VARCHAR(60) NOT NULL,
    columns       JSONB NOT NULL DEFAULT '[]',
    filters       JSONB NOT NULL DEFAULT '{}',
    is_shared     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_adhoc_report_query_owner ON adhoc_report_query(owner_user_id);
CREATE INDEX idx_adhoc_report_query_entity ON adhoc_report_query(entity);

CREATE TABLE adhoc_entity_whitelist (
    whitelist_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_name     VARCHAR(60) NOT NULL UNIQUE,
    allowed_columns JSONB NOT NULL DEFAULT '[]',
    allowed_roles   JSONB NOT NULL DEFAULT '[]',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_adhoc_entity_whitelist_entity ON adhoc_entity_whitelist(entity_name);

-- BR-RPT-14/15: adhoc_report_query.entity and the "entity" key inside
-- adhoc_report_query.columns/filters must stay governed by this
-- whitelist; enforced at the application/resolver layer (whitelist
-- lookups are normal SELECTs, not a DB-level FK, since entity_name
-- here names a logical entity, not a literal catalog of all tables).

CREATE TABLE aml_screening_flag (
    flag_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id             UUID NOT NULL REFERENCES order_txn(order_id),
    indication_type      VARCHAR(60) NOT NULL,
    investigation_status aml_investigation_status_enum NOT NULL DEFAULT 'NEW',
    flagged_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at          TIMESTAMPTZ,
    resolved_by          UUID REFERENCES user_account(user_id),
    CONSTRAINT chk_aml_screening_flag_resolution
        CHECK (
            (investigation_status IN ('RESOLVED','REPORTED_TO_PPATK') AND resolved_at IS NOT NULL)
            OR (investigation_status IN ('NEW','UNDER_INVESTIGATION') AND resolved_at IS NULL)
        )
);
CREATE INDEX idx_aml_screening_flag_order ON aml_screening_flag(order_id);
CREATE INDEX idx_aml_screening_flag_status ON aml_screening_flag(investigation_status);
