-- ============================================================
-- 05_sales_distribution.sql — Domain 2 (part 2)
-- SELLING_AGENT, DISTRIBUTION_NETWORK, SALES_PERSON,
-- COMMISSION_SCHEDULE, AGENT_FEE_FORMULA
-- + deferred FK: customer.agent_id -> selling_agent.agent_id
-- ============================================================

CREATE TABLE selling_agent (
    agent_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_code VARCHAR(20) NOT NULL UNIQUE,
    agent_name VARCHAR(150) NOT NULL,
    region     VARCHAR(60),
    license_no VARCHAR(40),
    status     agent_status_enum NOT NULL DEFAULT 'ACTIVE'
);

ALTER TABLE customer
    ADD CONSTRAINT fk_customer_agent FOREIGN KEY (agent_id) REFERENCES selling_agent(agent_id);
CREATE INDEX idx_customer_agent ON customer(agent_id);

CREATE TABLE distribution_network (
    network_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id     UUID NOT NULL REFERENCES selling_agent(agent_id),
    channel_type channel_type_enum NOT NULL,
    parent_group VARCHAR(100)
);
CREATE INDEX idx_distribution_network_agent ON distribution_network(agent_id);

CREATE TABLE sales_person (
    person_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id  UUID NOT NULL REFERENCES selling_agent(agent_id),
    name      VARCHAR(150) NOT NULL,
    role      VARCHAR(60)
);
CREATE INDEX idx_sales_person_agent ON sales_person(agent_id);

CREATE TABLE commission_schedule (
    schedule_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id       UUID NOT NULL REFERENCES selling_agent(agent_id),
    product_id     UUID NOT NULL REFERENCES product(product_id),
    rate           NUMERIC(7,4) NOT NULL,
    effective_date DATE NOT NULL,
    end_date       DATE,
    payment_status commission_payment_status_enum NOT NULL DEFAULT 'PENDING',
    CONSTRAINT chk_commission_schedule_dates CHECK (end_date IS NULL OR end_date >= effective_date)
);
CREATE INDEX idx_commission_schedule_lookup ON commission_schedule(agent_id, product_id, effective_date DESC);

CREATE TABLE agent_fee_formula (
    assignment_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id       UUID NOT NULL REFERENCES selling_agent(agent_id),
    product_id     UUID NOT NULL REFERENCES product(product_id),
    formula_id     UUID NOT NULL REFERENCES fee_formula(formula_id),
    effective_date DATE NOT NULL,
    expiry_date    DATE,
    CONSTRAINT chk_agent_fee_formula_dates CHECK (expiry_date IS NULL OR expiry_date >= effective_date)
);
CREATE INDEX idx_agent_fee_formula_lookup ON agent_fee_formula(agent_id, product_id, effective_date DESC);

CREATE OR REPLACE FUNCTION check_agent_fee_formula() RETURNS TRIGGER AS $$
DECLARE
    f_scope fee_scope_enum;
BEGIN
    SELECT scope INTO f_scope FROM fee_formula WHERE formula_id = NEW.formula_id;
    IF f_scope <> 'FEE_SHARING' THEN
        RAISE EXCEPTION 'agent_fee_formula.formula_id must reference a FEE_SHARING-scope fee_formula (got %)', f_scope;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_agent_fee_formula
    BEFORE INSERT OR UPDATE ON agent_fee_formula
    FOR EACH ROW EXECUTE FUNCTION check_agent_fee_formula();
