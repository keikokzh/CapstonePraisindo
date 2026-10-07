package services_test

import (
	"bytes"
	"fmt"
	"strings"
	"testing"

	"github.com/capstonePraisindo/reporting-service/internal/models"
	"github.com/capstonePraisindo/reporting-service/internal/services"
	"github.com/shopspring/decimal"
	"github.com/xuri/excelize/v2"
)

func createSampleRows(count int) []models.SubscriptionRow {
	rows := make([]models.SubscriptionRow, count)
	settleDate := "2026-08-15"
	for i := 0; i < count; i++ {
		rows[i] = models.SubscriptionRow{
			OrderID:         fmt.Sprintf("ord-%d", i+1),
			TransactionCode: "SUB260810-2101",
			BusinessDate:    "2026-08-10",
			CustomerName:    "Andi Wijaya",
			CIF:             "9001-882",
			SID:             "IDSID0009001882",
			ProductName:     "Praisindo Equity Fund",
			ProductCode:     "EQ-001",
			ChannelType:     "Direct — Kantor Cabang",
			Units:           decimal.RequireFromString("26859.5153"),
			NAVPerUnit:      decimal.RequireFromString("1842.5500"),
			GrossAmount:     decimal.RequireFromString("50000000.00"),
			FeeAmount:       decimal.RequireFromString("500000.00"),
			StampDuty:       decimal.RequireFromString("10000.00"),
			NetAmount:       decimal.RequireFromString("49490000.00"),
			LifecycleStatus: "SETTLED",
			SettlementDate:  &settleDate,
		}
	}
	return rows
}

func TestExportCSV(t *testing.T) {
	svc := services.NewExportService()
	rows := createSampleRows(3)

	data, err := svc.ExportCSV(rows)
	if err != nil {
		t.Fatalf("ExportCSV failed: %v", err)
	}

	// 1. Verify UTF-8 BOM
	if len(data) < 3 || data[0] != 0xEF || data[1] != 0xBB || data[2] != 0xBF {
		t.Errorf("Expected UTF-8 BOM at the beginning of CSV")
	}

	content := string(data)

	// 2. Verify Headers
	expectedHeaders := "Transaction ID,Trade Date,Customer,CIF,SID,Fund,Channel,Units,NAV/Unit,Gross Amount,Fee,Stamp Duty,Net Amount,Status,Settlement Date"
	if !strings.Contains(content, expectedHeaders) {
		t.Errorf("CSV missing expected headers. Got:\n%s", content)
	}

	// 3. Verify Row content
	if !strings.Contains(content, "SUB260810-2101") {
		t.Errorf("CSV missing transaction code")
	}
	if !strings.Contains(content, "Andi Wijaya") {
		t.Errorf("CSV missing customer name")
	}
	if !strings.Contains(content, "49490000.00") {
		t.Errorf("CSV missing net amount")
	}
}

func TestExportExcel(t *testing.T) {
	svc := services.NewExportService()
	rows := createSampleRows(5)
	filter := models.SubscriptionFilter{
		FromDate: "2026-08-01",
		ToDate:   "2026-08-31",
	}

	data, err := svc.ExportExcel(rows, filter)
	if err != nil {
		t.Fatalf("ExportExcel failed: %v", err)
	}

	// Open with excelize to verify valid XLSX structure
	f, err := excelize.OpenReader(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("Failed to parse generated Excel file: %v", err)
	}
	defer f.Close()

	// Check sheet name
	sheets := f.GetSheetList()
	if len(sheets) == 0 || sheets[0] != "Subscription Report" {
		t.Errorf("Expected sheet name 'Subscription Report', got: %v", sheets)
	}

	// Read header cell values
	val, err := f.GetCellValue("Subscription Report", "A4")
	if err != nil || val != "Transaction ID" {
		t.Errorf("Expected A4 to be 'Transaction ID', got '%s'", val)
	}

	// Check row data in A5
	val, _ = f.GetCellValue("Subscription Report", "A5")
	if val != "SUB260810-2101" {
		t.Errorf("Expected A5 to be 'SUB260810-2101', got '%s'", val)
	}
}

func TestExportPDF_MultiPage(t *testing.T) {
	svc := services.NewExportService()
	// Create 50 rows to test pagination across multiple pages
	rows := createSampleRows(50)
	filter := models.SubscriptionFilter{
		FromDate: "2026-08-01",
		ToDate:   "2026-08-31",
	}
	kpi := models.KPISummary{
		TotalNetSubscription: decimal.RequireFromString("2474500000.00"),
		TotalUnits:           decimal.RequireFromString("1342975.7650"),
		TotalTransactions:    50,
		AvgTicketSize:        decimal.RequireFromString("49490000.00"),
		PendingCount:         0,
	}
	totals := models.TotalsSummary{
		Units:       decimal.RequireFromString("1342975.7650"),
		GrossAmount: decimal.RequireFromString("2500000000.00"),
		FeeAmount:   decimal.RequireFromString("25000000.00"),
		StampDuty:   decimal.RequireFromString("500000.00"),
		NetAmount:   decimal.RequireFromString("2474500000.00"),
	}

	data, err := svc.ExportPDF(rows, filter, kpi, totals)
	if err != nil {
		t.Fatalf("ExportPDF failed: %v", err)
	}

	// Verify PDF magic bytes '%PDF-'
	if len(data) < 5 || string(data[:5]) != "%PDF-" {
		t.Errorf("Expected valid PDF magic bytes %%PDF-, got %s", string(data[:5]))
	}

	if len(data) < 10000 {
		t.Errorf("Expected multi-page PDF output size > 10KB, got %d bytes", len(data))
	}
}
