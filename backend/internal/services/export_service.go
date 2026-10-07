// Package services implements export functionality for TRX-01 report.
// Export files follow the same filter as the on-screen view and include ALL
// matching records (not just the current page).
//
// Technology choices:
//   - CSV: standard encoding/csv (no external dependency)
//   - Excel: excelize/v2 — mature, well-maintained Go library for .xlsx
//   - PDF: gofpdf — lightweight, supports headers/footers on every page,
//     table header repetition, and page numbers. Chosen over heavy wkhtmltopdf
//     to keep the Go binary self-contained without system dependencies.
package services

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"strings"

	"github.com/capstonePraisindo/reporting-service/internal/models"
	"github.com/jung-kurt/gofpdf"
	"github.com/shopspring/decimal"
	"github.com/xuri/excelize/v2"
)

type ExportService struct{}

func NewExportService() *ExportService {
	return &ExportService{}
}

// headers shared across CSV/Excel/PDF
var reportHeaders = []string{
	"Transaction ID", "Trade Date", "Customer", "CIF", "SID",
	"Fund", "Channel", "Units", "NAV/Unit",
	"Gross Amount", "Fee", "Stamp Duty", "Net Amount",
	"Status", "Settlement Date",
}

func fmtDecimal(d decimal.Decimal, places int32) string {
	return d.StringFixed(places)
}

func fmtSettDate(s *string) string {
	if s == nil {
		return "—"
	}
	return *s
}

// ExportCSV generates CSV bytes from rows
func (s *ExportService) ExportCSV(rows []models.SubscriptionRow) ([]byte, error) {
	var buf bytes.Buffer
	// BOM for Excel UTF-8 compatibility
	buf.Write([]byte{0xEF, 0xBB, 0xBF})

	w := csv.NewWriter(&buf)
	if err := w.Write(reportHeaders); err != nil {
		return nil, err
	}

	for _, r := range rows {
		record := []string{
			r.TransactionCode,
			dateOnly(r.BusinessDate),
			r.CustomerName,
			r.CIF,
			r.SID,
			r.ProductName,
			r.ChannelType,
			fmtDecimal(r.Units, 4),
			fmtDecimal(r.NAVPerUnit, 4),
			fmtDecimal(r.GrossAmount, 2),
			fmtDecimal(r.FeeAmount, 2),
			fmtDecimal(r.StampDuty, 2),
			fmtDecimal(r.NetAmount, 2),
			r.LifecycleStatus,
			fmtSettDate(r.SettlementDate),
		}
		if err := w.Write(record); err != nil {
			return nil, err
		}
	}

	w.Flush()
	return buf.Bytes(), w.Error()
}

// ExportExcel generates XLSX bytes from rows
func (s *ExportService) ExportExcel(rows []models.SubscriptionRow, filter models.SubscriptionFilter) ([]byte, error) {
	f := excelize.NewFile()
	defer f.Close()
	sheet := "Subscription Report"
	f.SetSheetName("Sheet1", sheet)

	// Title row
	f.SetCellValue(sheet, "A1", "Report: Subscription per Produk")
	titleStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true, Size: 14},
	})
	f.SetCellStyle(sheet, "A1", "A1", titleStyle)

	// Period row
	f.SetCellValue(sheet, "A2", fmt.Sprintf("Periode: %s s/d %s", filter.FromDate, filter.ToDate))

	// Header row (row 4)
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 10, Color: "#FFFFFF"},
		Fill:      excelize.Fill{Type: "pattern", Pattern: 1, Color: []string{"#2563EB"}},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
		Border: []excelize.Border{
			{Type: "bottom", Color: "#1D4ED8", Style: 1},
		},
	})

	cols := []string{"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"}
	for i, h := range reportHeaders {
		cell := fmt.Sprintf("%s4", cols[i])
		f.SetCellValue(sheet, cell, h)
		f.SetCellStyle(sheet, cell, cell, headerStyle)
	}

	// Data rows
	numStyle, _ := f.NewStyle(&excelize.Style{
		NumFmt: 4, // #,##0.00
	})

	precisionStyle, _ := f.NewStyle(&excelize.Style{CustomNumFmt: strPtr("#,##0.0000")})
	for i, r := range rows {
		row := i + 5
		f.SetCellValue(sheet, fmt.Sprintf("A%d", row), r.TransactionCode)
		f.SetCellValue(sheet, fmt.Sprintf("B%d", row), r.BusinessDate)
		f.SetCellValue(sheet, fmt.Sprintf("C%d", row), r.CustomerName)
		f.SetCellValue(sheet, fmt.Sprintf("D%d", row), r.CIF)
		f.SetCellValue(sheet, fmt.Sprintf("E%d", row), r.SID)
		f.SetCellValue(sheet, fmt.Sprintf("F%d", row), r.ProductName)
		f.SetCellValue(sheet, fmt.Sprintf("G%d", row), r.ChannelType)

		unitsF, _ := r.Units.Float64()
		navF, _ := r.NAVPerUnit.Float64()
		grossF, _ := r.GrossAmount.Float64()
		feeF, _ := r.FeeAmount.Float64()
		stampF, _ := r.StampDuty.Float64()
		netF, _ := r.NetAmount.Float64()

		f.SetCellValue(sheet, fmt.Sprintf("H%d", row), unitsF)
		f.SetCellValue(sheet, fmt.Sprintf("I%d", row), navF)
		f.SetCellValue(sheet, fmt.Sprintf("J%d", row), grossF)
		f.SetCellValue(sheet, fmt.Sprintf("K%d", row), feeF)
		f.SetCellValue(sheet, fmt.Sprintf("L%d", row), stampF)
		f.SetCellValue(sheet, fmt.Sprintf("M%d", row), netF)

		// Apply number format to numeric columns
		for _, col := range []string{"H", "I", "J", "K", "L", "M"} {
			f.SetCellStyle(sheet, fmt.Sprintf("%s%d", col, row), fmt.Sprintf("%s%d", col, row), numStyle)
		}

		f.SetCellStyle(sheet, fmt.Sprintf("H%d", row), fmt.Sprintf("I%d", row), precisionStyle)
		f.SetCellValue(sheet, fmt.Sprintf("N%d", row), r.LifecycleStatus)
		f.SetCellValue(sheet, fmt.Sprintf("O%d", row), fmtSettDate(r.SettlementDate))
	}

	// Column widths
	widths := map[string]float64{
		"A": 18, "B": 14, "C": 22, "D": 12, "E": 20,
		"F": 28, "G": 24, "H": 14, "I": 14,
		"J": 18, "K": 14, "L": 14, "M": 18,
		"N": 22, "O": 16,
	}
	for col, w := range widths {
		f.SetColWidth(sheet, col, col, w)
	}

	var buf bytes.Buffer
	if err := f.Write(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// ExportPDF generates PDF bytes following the reference PDF layout:
// Title, period, filter summary, KPI summary, table with repeated headers,
// footer totals, and page numbers.
func (s *ExportService) ExportPDF(
	rows []models.SubscriptionRow,
	filter models.SubscriptionFilter,
	kpi models.KPISummary,
	totals models.TotalsSummary,
) ([]byte, error) {
	pdf := gofpdf.New("L", "mm", "A4", "") // Landscape for wide table
	pdf.SetAutoPageBreak(true, 15)

	// A4 landscape: 297 - 2*10 = 277mm. Keep every column inside margins.
	colWidths := []float64{21, 17, 24, 16, 17, 25, 13, 19, 16, 24, 19, 16, 24, 23, 17}
	var tableWidth float64
	for _, w := range colWidths {
		tableWidth += w
	}
	for i := range colWidths {
		colWidths[i] *= 277 / tableWidth
	}

	// Header/footer function — called on every page
	pdf.SetHeaderFuncMode(func() {
		pdf.SetFont("Helvetica", "B", 12)
		pdf.CellFormat(0, 8, "Report: Subscription per Produk", "", 1, "L", false, 0, "")
		pdf.SetFont("Helvetica", "", 8)
		pdf.CellFormat(0, 5, fmt.Sprintf("Periode: %s s/d %s", filter.FromDate, filter.ToDate), "", 1, "L", false, 0, "")

		// Filter summary
		filters := []string{}
		if filter.FundID != nil {
			filters = append(filters, fmt.Sprintf("Fund ID: %s", *filter.FundID))
		}
		if filter.Status != "" {
			filters = append(filters, fmt.Sprintf("Status: %s", filter.Status))
		}
		if filter.Channel != "" {
			filters = append(filters, fmt.Sprintf("Channel: %s", filter.Channel))
		}
		if filter.Tab != "" && filter.Tab != "ALL" {
			filters = append(filters, fmt.Sprintf("Tab: %s", filter.Tab))
		}
		if filter.Search != "" {
			filters = append(filters, "Search: "+filter.Search)
		}
		if len(filters) > 0 {
			pdf.MultiCell(277, 4, "Filter: "+strings.Join(filters, " | "), "", "L", false)
		}

		pdf.Ln(2)

		// Table header on every page
		pdf.SetFont("Helvetica", "B", 6)
		pdf.SetFillColor(37, 99, 235)
		pdf.SetTextColor(255, 255, 255)
		pdfHeaders := []string{
			"Transaction ID", "Trade Date", "Customer", "CIF", "SID",
			"Fund", "Channel", "Units", "NAV/Unit",
			"Gross Amount", "Fee", "Stamp Duty", "Net Amount",
			"Status", "Settle Date",
		}
		for i, h := range pdfHeaders {
			pdf.CellFormat(colWidths[i], 5, h, "1", 0, "C", true, 0, "")
		}
		pdf.Ln(-1)
		pdf.SetTextColor(0, 0, 0)
	}, true)

	pdf.SetFooterFunc(func() {
		pdf.SetY(-12)
		pdf.SetFont("Helvetica", "I", 7)
		pdf.CellFormat(0, 5, fmt.Sprintf("IMS 2026 - Unit Registry System | Halaman %d/{nb}", pdf.PageNo()), "", 0, "C", false, 0, "")
	})
	pdf.AliasNbPages("")

	pdf.AddPage()

	// KPI summary (first page only, after first header)
	pdf.SetFont("Helvetica", "", 7)
	pdf.SetFillColor(248, 250, 252)
	kpiItems := []string{
		fmt.Sprintf("Total Net: Rp %s", formatIDR(kpi.TotalNetSubscription)),
		fmt.Sprintf("Total Units: %s", fmtDecimal(kpi.TotalUnits, 2)),
		fmt.Sprintf("Total Txn: %d", kpi.TotalTransactions),
		fmt.Sprintf("Avg Ticket: Rp %s", formatIDR(kpi.AvgTicketSize)),
		fmt.Sprintf("Pending: %d", kpi.PendingCount),
	}
	for _, item := range kpiItems {
		pdf.CellFormat(277/5, 5, item, "1", 0, "C", true, 0, "")
	}
	pdf.Ln(7)

	// Data rows
	pdf.SetFont("Helvetica", "", 6)
	for _, r := range rows {
		cellData := []string{
			r.TransactionCode,
			dateOnly(r.BusinessDate),
			r.CustomerName,
			r.CIF,
			r.SID,
			r.ProductName,
			r.ChannelType,
			fmtDecimal(r.Units, 4),
			fmtDecimal(r.NAVPerUnit, 4),
			"Rp " + formatIDR(r.GrossAmount),
			"Rp " + formatIDR(r.FeeAmount),
			"Rp " + formatIDR(r.StampDuty),
			"Rp " + formatIDR(r.NetAmount),
			strings.ReplaceAll(r.LifecycleStatus, "_", " "),
			fmtSettDate(r.SettlementDate),
		}
		lineHeight := 3.2
		rowHeight := lineHeight
		for i, d := range cellData {
			lines := pdf.SplitLines([]byte(pdfText(d)), colWidths[i]-1)
			if h := float64(len(lines)) * lineHeight; h > rowHeight {
				rowHeight = h
			}
		}
		if pdf.GetY()+rowHeight > 195 {
			pdf.AddPage()
			pdf.SetFont("Helvetica", "", 6)
		}
		x, y := pdf.GetXY()
		for i, d := range cellData {
			align := "L"
			if i >= 7 && i <= 12 {
				align = "R"
			}
			pdf.Rect(x, y, colWidths[i], rowHeight, "D")
			pdf.SetXY(x+0.5, y)
			pdf.MultiCell(colWidths[i]-1, lineHeight, pdfText(d), "", align, false)
			x += colWidths[i]
		}
		pdf.SetXY(10, y+rowHeight)

	}

	if pdf.GetY()+5 > 195 {
		pdf.AddPage()
	}
	// Footer totals row
	pdf.SetFont("Helvetica", "B", 6)
	pdf.SetFillColor(241, 245, 249)
	totalLabel := fmt.Sprintf("TOTAL (%d records)", len(rows))
	labelWidth := colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4] + colWidths[5] + colWidths[6]
	pdf.CellFormat(labelWidth, 5, totalLabel, "1", 0, "L", true, 0, "")
	pdf.CellFormat(colWidths[7], 5, fmtDecimal(totals.Units, 4), "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[8], 5, "", "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[9], 5, "Rp "+formatIDR(totals.GrossAmount), "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[10], 5, "Rp "+formatIDR(totals.FeeAmount), "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[11], 5, "Rp "+formatIDR(totals.StampDuty), "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[12], 5, "Rp "+formatIDR(totals.NetAmount), "1", 0, "R", true, 0, "")
	pdf.CellFormat(colWidths[13]+colWidths[14], 5, "", "1", 0, "C", true, 0, "")

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), pdf.Error()
}

func formatIDR(d decimal.Decimal) string {
	// Format with thousand separators using Indonesian convention (dot separator)
	s := d.StringFixed(0)
	if len(s) <= 3 {
		return s
	}
	// Add dots as thousand separators
	var result []byte
	neg := false
	if s[0] == '-' {
		neg = true
		s = s[1:]
	}
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			result = append(result, '.')
		}
		result = append(result, byte(c))
	}
	if neg {
		return "-" + string(result)
	}
	return string(result)
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max-1] + "…"
}

func strPtr(s string) *string { return &s }
func dateOnly(s string) string {
	if len(s) > 10 {
		return s[:10]
	}
	return s
}
func pdfText(s string) string { return strings.NewReplacer("—", "-", "…", "...").Replace(s) }
