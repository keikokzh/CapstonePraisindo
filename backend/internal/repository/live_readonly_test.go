package repository_test

import (
	"bytes"
	"database/sql"
	"encoding/csv"
	"fmt"
	"github.com/capstonePraisindo/reporting-service/internal/models"
	"github.com/capstonePraisindo/reporting-service/internal/repository"
	"github.com/capstonePraisindo/reporting-service/internal/services"
	"github.com/joho/godotenv"
	"github.com/shopspring/decimal"
	"github.com/xuri/excelize/v2"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"os"
	"path/filepath"
	"testing"
)

// Opt-in read-only audit. Never executes migration, seed or updates to shared data.
func TestNeonReadOnlyCrosscheck(t *testing.T) {
	if os.Getenv("VERIFY_NEON_READONLY") != "1" {
		t.Skip("set VERIFY_NEON_READONLY=1 for explicit live read-only audit")
	}
	_ = godotenv.Load("../../.env")
	url := os.Getenv("DATABASE_URL_V2")
	if url == "" {
		t.Fatal("DATABASE_URL_V2 missing")
	}
	db, err := gorm.Open(postgres.Open(url), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal("database connection unavailable (credentials suppressed)")
	}
	tx := db.Begin(&sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if tx.Error != nil {
		t.Fatal("cannot begin read-only snapshot")
	}
	defer tx.Rollback()
	var dbName string
	if err = tx.Raw("SELECT current_database()").Scan(&dbName).Error; err != nil || dbName != "urs2026_v2" {
		t.Fatal("wrong target database")
	}
	repo := repository.NewSubscriptionRepository(tx)
	var dates struct {
		From string
		To   string
	}
	if err = tx.Raw("SELECT MIN(business_date)::text AS from, MAX(business_date)::text AS to FROM order_txn WHERE order_type='SUBSCRIPTION'").Scan(&dates).Error; err != nil {
		t.Fatal(err)
	}
	base := models.SubscriptionFilter{FromDate: dates.From, ToDate: dates.To, PageSize: 100, Tab: "ALL"}
	all, err := repo.GetSubscriptionReport(base)
	if err != nil {
		t.Fatal(err)
	}
	var raw struct {
		Count int64
		Net   decimal.Decimal
		Units decimal.Decimal
		Gross decimal.Decimal
		Fee   decimal.Decimal
		Stamp decimal.Decimal
	}
	if err = tx.Raw("SELECT COUNT(*) AS count, SUM(net_amount) AS net, SUM(units) AS units, SUM(gross_amount) AS gross, SUM(fee_amount) AS fee, SUM(stamp_duty) AS stamp FROM order_txn WHERE order_type='SUBSCRIPTION' AND business_date BETWEEN ? AND ?", dates.From, dates.To).Scan(&raw).Error; err != nil {
		t.Fatal(err)
	}
	if all.Pagination.TotalRecords != raw.Count || !all.KPI.TotalNetSubscription.Equal(raw.Net) || !all.Totals.Units.Equal(raw.Units) || !all.Totals.GrossAmount.Equal(raw.Gross) || !all.Totals.FeeAmount.Equal(raw.Fee) || !all.Totals.StampDuty.Equal(raw.Stamp) {
		t.Fatal("raw transaction aggregates differ from report: join duplication or aggregate bug")
	}
	seen := map[string]bool{}
	for _, row := range all.Data {
		if seen[row.OrderID] {
			t.Fatal("duplicate order in joined result")
		}
		seen[row.OrderID] = true
	}
	if all.TabCounts.All != all.TabCounts.Settled+all.TabCounts.Pending+all.TabCounts.Exception+all.TabCounts.Closed {
		t.Fatal("status groups do not cover all orders")
	}
	for _, tab := range []string{"SETTLED", "PENDING", "EXCEPTION", "CLOSED"} {
		f := base
		f.Tab = tab
		got, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		var want int64
		q := tx.Table("order_txn").Where("order_type='SUBSCRIPTION' AND business_date BETWEEN ? AND ?", dates.From, dates.To)
		if tab == "PENDING" {
			q = q.Where("lifecycle_status IN ('PENDING_FUND','PENDING_NAV','PENDING_SETTLEMENT')")
		} else {
			q = q.Where("lifecycle_status=?", tab)
		}
		if e = q.Count(&want).Error; e != nil {
			t.Fatal(e)
		}
		if got.Pagination.TotalRecords != want {
			t.Fatalf("tab %s count mismatch", tab)
		}
	}
	funds, e := repo.GetFunds()
	if e != nil {
		t.Fatal(e)
	}
	for _, fund := range funds {
		f := base
		f.FundID = &fund.ID
		got, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		var n int64
		tx.Table("order_txn").Where("order_type='SUBSCRIPTION' AND product_id=? AND business_date BETWEEN ? AND ?", fund.ID, dates.From, dates.To).Count(&n)
		if got.Pagination.TotalRecords != n {
			t.Fatal("fund filter mismatch")
		}
	}
	for _, status := range []string{"CLOSED", "PENDING_FUND"} {
		f := base
		f.Status = status
		got, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		for _, row := range got.Data {
			if row.LifecycleStatus != status {
				t.Fatal("status filter mismatch")
			}
		}
	}
	channels, e := repo.GetChannels()
	if e != nil {
		t.Fatal(e)
	}
	for _, channel := range channels {
		f := base
		f.Channel = channel.ChannelType
		got, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		for _, row := range got.Data {
			if row.ChannelType != channel.ChannelType {
				t.Fatal("channel mismatch")
			}
		}
	}
	if len(all.Data) > 0 {
		for _, term := range []string{all.Data[0].TransactionCode, all.Data[0].CIF, all.Data[0].SID} {
			f := base
			f.Search = term
			got, e := repo.GetSubscriptionReport(f)
			if e != nil {
				t.Fatal(e)
			}
			if len(got.Data) == 0 {
				t.Fatal("search yielded no match")
			}
		}
	}
	pageSeen := map[string]bool{}
	for page := 1; page <= int((raw.Count+2)/3); page++ {
		f := base
		f.PageSize = 3
		f.Page = page
		got, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		if !got.KPI.TotalNetSubscription.Equal(raw.Net) {
			t.Fatal("KPI limited to page")
		}
		for _, row := range got.Data {
			if pageSeen[row.OrderID] {
				t.Fatal("pagination repeated order")
			}
			pageSeen[row.OrderID] = true
		}
	}
	if len(pageSeen) != int(raw.Count) {
		t.Fatal("pagination missed rows")
	}
	empty := base
	empty.Search = "NONEXISTENT-QA-ORDER"
	none, e := repo.GetSubscriptionReport(empty)
	if e != nil || none.Pagination.TotalRecords != 0 || !none.KPI.TotalNetSubscription.IsZero() {
		t.Fatal("empty result mismatch")
	}
	svc := services.NewExportService()
	output := os.Getenv("VERIFY_EXPORT_DIR")
	for _, tab := range []string{"ALL", "CLOSED"} {
		f := base
		f.Tab = tab
		f.PageSize = 3
		f.Page = 1
		rows, e := repo.GetAllFilteredRows(f)
		if e != nil {
			t.Fatal(e)
		}
		report, e := repo.GetSubscriptionReport(f)
		if e != nil {
			t.Fatal(e)
		}
		if len(rows) != int(report.Pagination.TotalRecords) {
			t.Fatal("export limited to page")
		}
		csvData, e := svc.ExportCSV(rows)
		if e != nil {
			t.Fatal(e)
		}
		records, e := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(csvData, []byte{239, 187, 191}))).ReadAll()
		if e != nil || len(records) != len(rows)+1 {
			t.Fatal("CSV row count mismatch")
		}
		xlsx, e := svc.ExportExcel(rows, f)
		if e != nil {
			t.Fatal(e)
		}
		book, e := excelize.OpenReader(bytes.NewReader(xlsx))
		if e != nil {
			t.Fatal(e)
		}
		for i, row := range rows {
			if records[i+1][0] != row.TransactionCode || records[i+1][7] != row.Units.StringFixed(4) || records[i+1][12] != row.NetAmount.StringFixed(2) || records[i+1][13] != row.LifecycleStatus {
				t.Fatal("CSV content mismatch")
			}
			id, _ := book.GetCellValue("Subscription Report", fmt.Sprintf("A%d", i+5))
			net, _ := book.GetCellValue("Subscription Report", fmt.Sprintf("M%d", i+5), excelize.Options{RawCellValue: true})
			d, e := decimal.NewFromString(net)
			if id != row.TransactionCode || e != nil || !d.Equal(row.NetAmount) {
				t.Fatal("Excel content mismatch")
			}
		}
		book.Close()
		pdf, e := svc.ExportPDF(rows, f, report.KPI, report.Totals)
		if e != nil {
			t.Fatal(e)
		}
		if output != "" {
			if e = os.MkdirAll(output, 0700); e != nil {
				t.Fatal(e)
			}
			for ext, data := range map[string][]byte{"csv": csvData, "xlsx": xlsx, "pdf": pdf} {
				if e = os.WriteFile(filepath.Join(output, tab+"."+ext), data, 0600); e != nil {
					t.Fatal(e)
				}
			}
		}
	}
	// Multi-page fixture only in memory: no inserted database rows.
	if output != "" && len(all.Data) > 0 {
		rows := make([]models.SubscriptionRow, 90)
		totals := models.TotalsSummary{}
		for i := range rows {
			rows[i] = all.Data[i%len(all.Data)]
			rows[i].TransactionCode = fmt.Sprintf("QA-%04d", i+1)
			totals.Units = totals.Units.Add(rows[i].Units)
			totals.GrossAmount = totals.GrossAmount.Add(rows[i].GrossAmount)
			totals.FeeAmount = totals.FeeAmount.Add(rows[i].FeeAmount)
			totals.StampDuty = totals.StampDuty.Add(rows[i].StampDuty)
			totals.NetAmount = totals.NetAmount.Add(rows[i].NetAmount)
		}
		kpi := models.KPISummary{TotalTransactions: 90, TotalNetSubscription: totals.NetAmount, TotalUnits: totals.Units, AvgTicketSize: totals.NetAmount.Div(decimal.NewFromInt(90))}
		pdf, e := svc.ExportPDF(rows, base, kpi, totals)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(output, "MULTIPAGE.pdf"), pdf, 0600); e != nil {
			t.Fatal(e)
		}
	}
	t.Logf("READ-ONLY PASS database=%s period=%s..%s orders=%d net=%s units=%s statuses=%+v", dbName, dates.From, dates.To, raw.Count, raw.Net, raw.Units, all.TabCounts)
}
