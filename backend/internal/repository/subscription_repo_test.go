package repository

import (
	"github.com/capstonePraisindo/reporting-service/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"strings"
	"testing"
)

// SQL generation only: no network connection, migration, or seed.
func TestStatusFiltersForReportAndExport(t *testing.T) {
	db, err := gorm.Open(postgres.New(postgres.Config{DSN: "host=localhost dbname=unused user=unused sslmode=disable"}), &gorm.Config{DryRun: true, DisableAutomaticPing: true})
	if err != nil {
		t.Fatal(err)
	}
	repo := NewSubscriptionRepository(db)
	for _, tab := range []string{"CLOSED", "SETTLED", "EXCEPTION", "PENDING", "ALL"} {
		filter := models.SubscriptionFilter{FromDate: "2026-08-01", ToDate: "2026-10-31", Tab: tab}
		sql := db.ToSQL(func(tx *gorm.DB) *gorm.DB {
			local := *repo
			local.db = tx
			return local.buildBaseQuery(filter).Find(&[]models.SubscriptionRow{})
		})
		if !strings.Contains(sql, "o.order_type = 'SUBSCRIPTION'") {
			t.Fatal(sql)
		}
		switch tab {
		case "PENDING":
			for _, status := range []string{"PENDING_FUND", "PENDING_NAV", "PENDING_SETTLEMENT"} {
				if !strings.Contains(sql, "'"+status+"'") {
					t.Fatal(sql)
				}
			}
			if strings.Contains(sql, "'CLOSED'") {
				t.Fatal("Closed must not count as pending")
			}
		case "ALL":
			if strings.Contains(sql, "o.lifecycle_status =") || strings.Contains(sql, "o.lifecycle_status IN") {
				t.Fatal(sql)
			}
		default:
			if !strings.Contains(sql, "o.lifecycle_status = '"+tab+"'") {
				t.Fatal(sql)
			}
		}
	}
}
