-- ============================================================
-- 01_governance_users.sql — ROLE, USER_ACCOUNT, AUDIT_TRAIL
-- (Domain 5, created early since many FKs elsewhere point here)
-- ============================================================

CREATE TABLE role (
    role_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name   VARCHAR(60) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE user_account (
    user_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(150) NOT NULL,
    email      VARCHAR(150) NOT NULL UNIQUE,
    role_id    UUID NOT NULL REFERENCES role(role_id),
    status     user_status_enum NOT NULL DEFAULT 'ACTIVE'
);
CREATE INDEX idx_user_account_role ON user_account(role_id);

CREATE TABLE audit_trail (
    audit_id    BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES user_account(user_id),
    entity_name VARCHAR(60) NOT NULL,
    entity_id   VARCHAR(60) NOT NULL,
    action_code audit_action_enum NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_trail_entity ON audit_trail(entity_name, entity_id);
CREATE INDEX idx_audit_trail_user ON audit_trail(user_id);
CREATE INDEX idx_audit_trail_created_at ON audit_trail(created_at);
