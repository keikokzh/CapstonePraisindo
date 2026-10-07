-- Run all migrations in order against the target database.
-- Usage: psql -U postgres -d praisindo_ims2026 -f run_all.sql
\set ON_ERROR_STOP on
\i 00_extensions_and_types.sql
\i 01_governance_users.sql
\i 02_master_data.sql
\i 03_fee_formula.sql
\i 04_customer_registry.sql
\i 05_sales_distribution.sql
\i 06_transactions.sql
\i 07_netting.sql
\i 08_cash_settlement.sql
\i 09_reporting_governance.sql
\i 10_report_center_extensions.sql
\i 11_resolver_functions.sql
\i 12_seed_data.sql
\i 13_sample_data.sql
