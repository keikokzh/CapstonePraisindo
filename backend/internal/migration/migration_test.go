package migration

import (
	"gorm.io/gorm/schema"
	"strings"
	"testing"
	"testing/fstest"
)

func TestExplicitManifestExcludesLegacyAndRunAll(t *testing.T) {
	files := fstest.MapFS{}
	for _, name := range baseline {
		files["sql/"+name] = &fstest.MapFile{Data: []byte("SELECT 1;")}
	}
	files["sql/001_create_tables.sql"] = &fstest.MapFile{Data: []byte("DANGEROUS LEGACY")}
	files["sql/run_all.sql"] = &fstest.MapFile{Data: []byte(`\i legacy.sql`)}
	files["sql/99_unknown.sql"] = &fstest.MapFile{Data: []byte("UNKNOWN")}
	for _, withSample := range []bool{false, true} {
		scripts, err := Scripts(files, withSample)
		if err != nil {
			t.Fatal(err)
		}
		want := 13
		if withSample {
			want = 14
		}
		if len(scripts) != want {
			t.Fatalf("got %d files; want %d", len(scripts), want)
		}
		for _, s := range scripts {
			if s.SQL != "SELECT 1;" {
				t.Fatalf("unexpected script: %s", s.Version)
			}
		}
	}
	delete(files, "sql/06_transactions.sql")
	if _, err := Scripts(files, true); err == nil {
		t.Fatal("missing baseline must fail before execution")
	}
}

func TestExistingLedgerCompatibilityAndHistory(t *testing.T) {
	if name := (schema.NamingStrategy{}).TableName("SchemaMigrationV2"); name != "schema_migration_v2" {
		t.Fatalf("old ledger name: %s", name)
	}
	versions := []string{}
	for _, name := range baseline {
		versions = append(versions, strings.TrimSuffix(name, ".sql"))
	}
	for i := 0; i <= len(versions); i++ {
		if err := ValidateHistory(versions[:i]); err != nil {
			t.Fatal(err)
		}
	}
	for _, bad := range [][]string{{"001_create_tables"}, {versions[1]}, {versions[0], versions[2]}} {
		if ValidateHistory(bad) == nil {
			t.Fatalf("accepted invalid history %v", bad)
		}
	}
}

func TestEmbeddedBaselineReadable(t *testing.T) {
	scripts, err := Scripts(SQL, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(scripts) != 14 {
		t.Fatal("expected upstream 00–13")
	}
}
