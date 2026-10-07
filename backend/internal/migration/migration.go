// Package migration embeds the immutable upstream V2 baseline for reproducible installs.
package migration

import (
	"embed"
	"fmt"
	"gorm.io/gorm"
	"io/fs"
	"strings"
)

//go:embed sql/*.sql
var SQL embed.FS

var baseline = []string{
	"00_extensions_and_types.sql",
	"01_governance_users.sql",
	"02_master_data.sql",
	"03_fee_formula.sql",
	"04_customer_registry.sql",
	"05_sales_distribution.sql",
	"06_transactions.sql",
	"07_netting.sql",
	"08_cash_settlement.sql",
	"09_reporting_governance.sql",
	"10_report_center_extensions.sql",
	"11_resolver_functions.sql",
	"12_seed_data.sql",
	"13_sample_data.sql",
}

type Script struct {
	Version string
	SQL     string
}

// Scripts uses an explicit manifest, never a directory glob at execution time.
func Scripts(source fs.FS, includeSample bool) ([]Script, error) {
	names := baseline
	if !includeSample {
		names = names[:len(names)-1]
	}
	scripts := make([]Script, 0, len(names))
	for _, name := range names {
		data, err := fs.ReadFile(source, "sql/"+name)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", name, err)
		}
		scripts = append(scripts, Script{strings.TrimSuffix(name, ".sql"), string(data)})
	}
	return scripts, nil
}

// Apply preserves the previous runner's ledger naming convention. All pending
// files and their ledger records commit together, under a transaction-scoped lock.
func Apply(db *gorm.DB, includeSample bool) error {
	scripts, err := Scripts(SQL, includeSample)
	if err != nil {
		return err
	}
	return db.Transaction(func(tx *gorm.DB) error {
		var name string
		if err := tx.Raw("SELECT current_database()").Scan(&name).Error; err != nil {
			return err
		}
		if name != "urs2026_v2" {
			return fmt.Errorf("target must be urs2026_v2; got %s", name)
		}
		if err := tx.Exec("SELECT pg_advisory_xact_lock(2026, 1201)").Error; err != nil {
			return err
		}
		if err := tx.Exec("SET LOCAL search_path TO public").Error; err != nil {
			return err
		}
		// Same name used by the previous GORM SchemaMigrationV2 struct.
		ledger := tx.NamingStrategy.TableName("SchemaMigrationV2")
		if ledger != "schema_migration_v2" {
			return fmt.Errorf("unexpected migration ledger name: %s", ledger)
		}
		var exists bool
		if err := tx.Raw("SELECT to_regclass('public.schema_migration_v2') IS NOT NULL").Scan(&exists).Error; err != nil {
			return err
		}
		if !exists {
			var objects int64
			if err := tx.Raw(`SELECT
    (SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','S','f')) +
    (SELECT COUNT(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public' AND t.typtype='e')`).Scan(&objects).Error; err != nil {
				return err
			}
			if objects != 0 {
				return fmt.Errorf("database is not empty and has no V2 ledger; refusing baseline installation")
			}
		}
		if err := tx.Exec(`CREATE TABLE IF NOT EXISTS public.schema_migration_v2
    (version text PRIMARY KEY, applied_at timestamptz DEFAULT now())`).Error; err != nil {
			return err
		}
		var applied []string
		if err := tx.Table("public.schema_migration_v2").Order("version").Pluck("version", &applied).Error; err != nil {
			return err
		}
		if err := ValidateHistory(applied); err != nil {
			return err
		}
		// An empty ledger beside pre-existing tables is not a fresh database.
		if len(applied) == 0 {
			var tables int64
			if err := tx.Raw("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name <> 'schema_migration_v2'").Scan(&tables).Error; err != nil {
				return err
			}
			if tables != 0 {
				return fmt.Errorf("empty ledger with existing tables; manual audit required")
			}
		}
		for i, script := range scripts {
			if i < len(applied) {
				continue
			}
			if err := tx.Exec(script.SQL).Error; err != nil {
				return fmt.Errorf("migration %s failed: %w", script.Version, err)
			}
			if err := tx.Exec("INSERT INTO public.schema_migration_v2 (version) VALUES (?)", script.Version).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// Reject gaps/unknown history rather than trying to replay a partial baseline.
func ValidateHistory(applied []string) error {
	if len(applied) > len(baseline) {
		return fmt.Errorf("unknown V2 migration history")
	}
	for i, version := range applied {
		if version != strings.TrimSuffix(baseline[i], ".sql") {
			return fmt.Errorf("V2 history gap or unknown version: %s", version)
		}
	}
	return nil
}
