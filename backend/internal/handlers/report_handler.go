// Package handlers implements HTTP handlers for TRX-01 reporting endpoints
package handlers

import (
	"fmt"
	"net/http"
	"regexp"
	"time"

	"github.com/capstonePraisindo/reporting-service/internal/models"
	"github.com/capstonePraisindo/reporting-service/internal/repository"
	"github.com/capstonePraisindo/reporting-service/internal/services"
	"github.com/gin-gonic/gin"
)

type ReportHandler struct {
	repo          *repository.SubscriptionRepository
	exportService *services.ExportService
}

func NewReportHandler(repo *repository.SubscriptionRepository) *ReportHandler {
	return &ReportHandler{
		repo:          repo,
		exportService: services.NewExportService(),
	}
}

// GetSubscriptionReport handles GET /api/v1/reports/subscription-by-product
func (h *ReportHandler) GetSubscriptionReport(c *gin.Context) {
	var filter models.SubscriptionFilter
	if err := c.ShouldBindQuery(&filter); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Parameter tidak valid",
			"details": err.Error(),
		})
		return
	}

	if err := validateFilter(filter); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := h.repo.GetSubscriptionReport(filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Gagal mengambil data laporan",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, result)
}

// ExportSubscriptionReport handles GET /api/v1/reports/subscription-by-product/export
func (h *ReportHandler) ExportSubscriptionReport(c *gin.Context) {
	var filter models.SubscriptionFilter
	if err := c.ShouldBindQuery(&filter); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Parameter tidak valid", "details": err.Error()})
		return
	}

	if err := validateFilter(filter); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	format := c.Query("format")
	if format == "" {
		format = "csv"
	}

	// Get ALL filtered rows for export (no pagination)
	rows, err := h.repo.GetAllFilteredRows(filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil data untuk ekspor"})
		return
	}

	timestamp := time.Now().Format("20060102_150405")

	switch format {
	case "csv":
		data, err := h.exportService.ExportCSV(rows)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal membuat file CSV"})
			return
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=subscription_report_%s.csv", timestamp))
		c.Data(http.StatusOK, "text/csv; charset=utf-8", data)

	case "xlsx":
		data, err := h.exportService.ExportExcel(rows, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal membuat file Excel"})
			return
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=subscription_report_%s.xlsx", timestamp))
		c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)

	case "pdf":
		// Need KPI and totals for PDF
		reportData, err := h.repo.GetSubscriptionReport(filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil data KPI"})
			return
		}
		data, err := h.exportService.ExportPDF(rows, filter, reportData.KPI, reportData.Totals)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal membuat file PDF"})
			return
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=subscription_report_%s.pdf", timestamp))
		c.Data(http.StatusOK, "application/pdf", data)

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Format tidak didukung. Gunakan: csv, xlsx, pdf"})
	}
}

// GetFunds handles GET /api/v1/funds
func (h *ReportHandler) GetFunds(c *gin.Context) {
	funds, err := h.repo.GetFunds()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil daftar fund"})
		return
	}
	c.JSON(http.StatusOK, funds)
}

// GetChannels handles GET /api/v1/channels
func (h *ReportHandler) GetChannels(c *gin.Context) {
	channels, err := h.repo.GetChannels()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil daftar channel"})
		return
	}
	c.JSON(http.StatusOK, channels)
}

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func validateFilter(f models.SubscriptionFilter) error {
	from, err := time.Parse("2006-01-02", f.FromDate)
	if err != nil {
		return fmt.Errorf("Format from_date tidak valid (YYYY-MM-DD)")
	}
	to, err := time.Parse("2006-01-02", f.ToDate)
	if err != nil {
		return fmt.Errorf("Format to_date tidak valid (YYYY-MM-DD)")
	}
	if to.Before(from) {
		return fmt.Errorf("to_date tidak boleh sebelum from_date")
	}
	if f.FundID != nil && !uuidPattern.MatchString(*f.FundID) {
		return fmt.Errorf("fund_id harus berupa UUID")
	}
	switch f.Status {
	case "", "SETTLED", "CLOSED", "PENDING_FUND", "PENDING_NAV", "PENDING_SETTLEMENT", "EXCEPTION":
	default:
		return fmt.Errorf("Status tidak valid")
	}
	switch f.Tab {
	case "", "ALL", "SETTLED", "CLOSED", "PENDING", "EXCEPTION":
	default:
		return fmt.Errorf("Tab tidak valid")
	}
	return nil
}
