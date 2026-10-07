// Package repository implements database queries for TRX-01 report.
// Query design follows FSD Reporting Module §11 outline for Subscription per Produk:
//
//	SELECT from order_txn
//	JOIN product, customer, investor_account, selling_agent, distribution_network
//	WHERE order_type = 'SUBSCRIPTION' AND business_date BETWEEN ? AND ?
//
// KPI and totals are computed across ALL filtered records (not just current page)
// to ensure consistency — this matches the mockup behavior where footer totals
// reflect the entire result set.
//
// IMPORTANT: The JOIN path uses LEFT JOINs for agent/channel (nullable) and
// investor_account (may not exist for all product+cif combos) to avoid
// silently dropping transactions. LEFT JOIN does not guarantee uniqueness;
// account, channel and settlement cardinalities still need business validation.
package repository

import (
	"fmt"
	"math"
	"strings"

	"github.com/capstonePraisindo/reporting-service/internal/models"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

type SubscriptionRepository struct {
	db *gorm.DB
}

func NewSubscriptionRepository(db *gorm.DB) *SubscriptionRepository {
	return &SubscriptionRepository{db: db}
}

// buildBaseQuery creates the filtered query without pagination
// This is reused for both data retrieval and aggregate computation
func (r *SubscriptionRepository) buildBaseQuery(filter models.SubscriptionFilter) *gorm.DB {
	query := r.db.Table("order_txn o").
		Select(`
			o.order_id,
			'TX-' || UPPER(RIGHT(o.order_id::text, 8)) as transaction_code,
			o.business_date,
			o.gross_amount,
			o.fee_amount,
			o.stamp_duty,
			o.net_amount,
			o.units,
			COALESCE(pn.nav_per_unit, 0) as nav_per_unit,
			o.lifecycle_status,
			si.settlement_date,
			o.cif,
			c.customer_name,
			COALESCE(ia.sid, '') as sid,
			p.product_name,
			p.product_code,
			COALESCE(dn.channel_type::text, 'Direct') as channel_type
		`).
		Joins("JOIN customer c ON c.cif = o.cif").
		Joins("JOIN product p ON p.product_id = o.product_id").
		// Asumsi Data Model: 1 CIF memiliki 1 akun aktif per produk.
		Joins("LEFT JOIN investor_account ia ON ia.cif = o.cif AND ia.product_id = o.product_id AND ia.status = 'ACTIVE'").
		Joins("LEFT JOIN selling_agent sa ON sa.agent_id = o.agent_id").
		Joins("LEFT JOIN distribution_network dn ON dn.agent_id = sa.agent_id").
		Joins("LEFT JOIN product_nav pn ON pn.product_id = o.product_id AND pn.nav_date = o.business_date").
		Joins("LEFT JOIN settlement_instruction si ON si.order_id = o.order_id").
		Where("o.order_type = ?", "SUBSCRIPTION").
		Where("o.business_date >= ?", filter.FromDate).
		Where("o.business_date <= ?", filter.ToDate)

	// Fund filter
	if filter.FundID != nil {
		query = query.Where("o.product_id = ?", *filter.FundID)
	}

	// Status filter (from dropdown)
	if filter.Status != "" {
		query = query.Where("o.lifecycle_status = ?", filter.Status)
	}

	// Channel filter
	if filter.Channel != "" {
		query = query.Where("dn.channel_type = ?", filter.Channel)
	}

	// Tab filter (quick chips)
	switch filter.Tab {
	case "SETTLED":
		query = query.Where("o.lifecycle_status = ?", "SETTLED")
	case "PENDING":
		query = query.Where("o.lifecycle_status IN ?", []string{"PENDING_FUND", "PENDING_NAV", "PENDING_SETTLEMENT"})
	case "EXCEPTION", "CLOSED":
		query = query.Where("o.lifecycle_status = ?", filter.Tab)
	}

	// Search filter
	if filter.Search != "" {
		searchTerm := "%" + strings.ToLower(filter.Search) + "%"
		query = query.Where(
			"(LOWER(o.order_id::text) LIKE ? OR LOWER('TX-' || RIGHT(o.order_id::text, 8)) LIKE ? OR LOWER(c.customer_name) LIKE ? OR LOWER(COALESCE(ia.sid, '')) LIKE ? OR LOWER(o.cif) LIKE ?)",
			searchTerm, searchTerm, searchTerm, searchTerm, searchTerm,
		)
	}

	return query
}

// GetSubscriptionReport returns paginated data with KPIs and totals
func (r *SubscriptionRepository) GetSubscriptionReport(filter models.SubscriptionFilter) (*models.SubscriptionReportResponse, error) {
	filter.Defaults()

	baseQuery := r.buildBaseQuery(filter)

	// 1. Count total records
	var totalRecords int64
	if err := baseQuery.Count(&totalRecords).Error; err != nil {
		return nil, fmt.Errorf("count query failed: %w", err)
	}

	// 2. Get aggregates for KPI and totals (across ALL filtered records)
	type Aggregates struct {
		TotalNet       decimal.Decimal `gorm:"column:total_net"`
		TotalUnits     decimal.Decimal `gorm:"column:total_units"`
		TotalGross     decimal.Decimal `gorm:"column:total_gross"`
		TotalFee       decimal.Decimal `gorm:"column:total_fee"`
		TotalStampDuty decimal.Decimal `gorm:"column:total_stamp_duty"`
		PendingCount   int64           `gorm:"column:pending_count"`
	}

	var agg Aggregates
	aggQuery := r.buildBaseQuery(filter).Select(`
		COALESCE(SUM(o.net_amount), 0) as total_net,
		COALESCE(SUM(o.units), 0) as total_units,
		COALESCE(SUM(o.gross_amount), 0) as total_gross,
		COALESCE(SUM(o.fee_amount), 0) as total_fee,
		COALESCE(SUM(o.stamp_duty), 0) as total_stamp_duty,
		COUNT(CASE WHEN o.lifecycle_status IN ('PENDING_FUND','PENDING_NAV','PENDING_SETTLEMENT') THEN 1 END) as pending_count
	`)
	if err := aggQuery.Scan(&agg).Error; err != nil {
		return nil, fmt.Errorf("aggregate query failed: %w", err)
	}

	// 3. Get tab counts (these use base filter WITHOUT tab restriction)
	tabFilter := filter
	tabFilter.Tab = "ALL"
	tabFilter.Status = ""
	tabBaseQuery := r.buildBaseQuery(tabFilter)

	type TabCountResult struct {
		AllCount       int64 `gorm:"column:all_count"`
		SettledCount   int64 `gorm:"column:settled_count"`
		PendingCount   int64 `gorm:"column:pending_count"`
		ExceptionCount int64 `gorm:"column:exception_count"`
		ClosedCount    int64 `gorm:"column:closed_count"`
	}

	var tc TabCountResult
	tcQuery := tabBaseQuery.Select(`
		COUNT(*) as all_count,
		COUNT(CASE WHEN o.lifecycle_status = 'SETTLED' THEN 1 END) as settled_count,
		COUNT(CASE WHEN o.lifecycle_status IN ('PENDING_FUND','PENDING_NAV','PENDING_SETTLEMENT') THEN 1 END) as pending_count,
		COUNT(CASE WHEN o.lifecycle_status = 'EXCEPTION' THEN 1 END) as exception_count,
		COUNT(CASE WHEN o.lifecycle_status = 'CLOSED' THEN 1 END) as closed_count
	`)
	if err := tcQuery.Scan(&tc).Error; err != nil {
		return nil, fmt.Errorf("tab count query failed: %w", err)
	}

	// 4. Get paginated data with stable ordering
	validSortCols := map[string]string{
		"business_date":    "o.business_date",
		"transaction_code": "RIGHT(o.order_id::text, 8)",
		"customer_name":    "c.customer_name",
		"gross_amount":     "o.gross_amount",
		"net_amount":       "o.net_amount",
		"units":            "o.units",
		"lifecycle_status": "o.lifecycle_status",
	}

	sortCol, ok := validSortCols[filter.SortBy]
	if !ok {
		sortCol = "o.business_date"
	}
	sortDir := "DESC"
	if strings.ToLower(filter.SortOrder) == "asc" {
		sortDir = "ASC"
	}
	// Add secondary sort by order_id for stable ordering
	orderClause := fmt.Sprintf("%s %s, o.order_id ASC", sortCol, sortDir)

	offset := (filter.Page - 1) * filter.PageSize

	type RawRow struct {
		OrderID         string          `gorm:"column:order_id"`
		TransactionCode string          `gorm:"column:transaction_code"`
		BusinessDate    string          `gorm:"column:business_date"`
		CustomerName    string          `gorm:"column:customer_name"`
		CIF             string          `gorm:"column:cif"`
		SID             string          `gorm:"column:sid"`
		ProductName     string          `gorm:"column:product_name"`
		ProductCode     string          `gorm:"column:product_code"`
		ChannelType     string          `gorm:"column:channel_type"`
		Units           decimal.Decimal `gorm:"column:units"`
		NAVPerUnit      decimal.Decimal `gorm:"column:nav_per_unit"`
		GrossAmount     decimal.Decimal `gorm:"column:gross_amount"`
		FeeAmount       decimal.Decimal `gorm:"column:fee_amount"`
		StampDuty       decimal.Decimal `gorm:"column:stamp_duty"`
		NetAmount       decimal.Decimal `gorm:"column:net_amount"`
		LifecycleStatus string          `gorm:"column:lifecycle_status"`
		SettlementDate  *string         `gorm:"column:settlement_date"`
	}

	var rawRows []RawRow
	dataQuery := r.buildBaseQuery(filter).
		Order(orderClause).
		Offset(offset).
		Limit(filter.PageSize)

	if err := dataQuery.Scan(&rawRows).Error; err != nil {
		return nil, fmt.Errorf("data query failed: %w", err)
	}

	// Convert to DTO rows
	rows := make([]models.SubscriptionRow, len(rawRows))
	for i, rr := range rawRows {
		rows[i] = models.SubscriptionRow{
			OrderID:         rr.OrderID,
			TransactionCode: rr.TransactionCode,
			BusinessDate:    rr.BusinessDate,
			CustomerName:    rr.CustomerName,
			CIF:             rr.CIF,
			SID:             rr.SID,
			ProductName:     rr.ProductName,
			ProductCode:     rr.ProductCode,
			ChannelType:     rr.ChannelType,
			Units:           rr.Units,
			NAVPerUnit:      rr.NAVPerUnit,
			GrossAmount:     rr.GrossAmount,
			FeeAmount:       rr.FeeAmount,
			StampDuty:       rr.StampDuty,
			NetAmount:       rr.NetAmount,
			LifecycleStatus: rr.LifecycleStatus,
			SettlementDate:  rr.SettlementDate,
		}
	}

	// Compute avg ticket size
	avgTicket := decimal.Zero
	if totalRecords > 0 {
		avgTicket = agg.TotalNet.Div(decimal.NewFromInt(totalRecords))
	}

	totalPages := int(math.Ceil(float64(totalRecords) / float64(filter.PageSize)))

	return &models.SubscriptionReportResponse{
		Data: rows,
		Pagination: models.Pagination{
			Page:         filter.Page,
			PageSize:     filter.PageSize,
			TotalRecords: totalRecords,
			TotalPages:   totalPages,
		},
		KPI: models.KPISummary{
			TotalNetSubscription: agg.TotalNet,
			TotalUnits:           agg.TotalUnits,
			TotalTransactions:    totalRecords,
			AvgTicketSize:        avgTicket,
			PendingCount:         agg.PendingCount,
		},
		Totals: models.TotalsSummary{
			Units:       agg.TotalUnits,
			GrossAmount: agg.TotalGross,
			FeeAmount:   agg.TotalFee,
			StampDuty:   agg.TotalStampDuty,
			NetAmount:   agg.TotalNet,
		},
		TabCounts: models.TabCounts{
			All:       tc.AllCount,
			Settled:   tc.SettledCount,
			Pending:   tc.PendingCount,
			Exception: tc.ExceptionCount,
			Closed:    tc.ClosedCount,
		},
	}, nil
}

// GetAllFilteredRows returns ALL rows matching filter (no pagination) for export
func (r *SubscriptionRepository) GetAllFilteredRows(filter models.SubscriptionFilter) ([]models.SubscriptionRow, error) {
	type RawRow struct {
		OrderID         string          `gorm:"column:order_id"`
		TransactionCode string          `gorm:"column:transaction_code"`
		BusinessDate    string          `gorm:"column:business_date"`
		CustomerName    string          `gorm:"column:customer_name"`
		CIF             string          `gorm:"column:cif"`
		SID             string          `gorm:"column:sid"`
		ProductName     string          `gorm:"column:product_name"`
		ProductCode     string          `gorm:"column:product_code"`
		ChannelType     string          `gorm:"column:channel_type"`
		Units           decimal.Decimal `gorm:"column:units"`
		NAVPerUnit      decimal.Decimal `gorm:"column:nav_per_unit"`
		GrossAmount     decimal.Decimal `gorm:"column:gross_amount"`
		FeeAmount       decimal.Decimal `gorm:"column:fee_amount"`
		StampDuty       decimal.Decimal `gorm:"column:stamp_duty"`
		NetAmount       decimal.Decimal `gorm:"column:net_amount"`
		LifecycleStatus string          `gorm:"column:lifecycle_status"`
		SettlementDate  *string         `gorm:"column:settlement_date"`
	}

	var rawRows []RawRow
	query := r.buildBaseQuery(filter).Order("o.business_date DESC, o.order_id ASC")

	if err := query.Scan(&rawRows).Error; err != nil {
		return nil, fmt.Errorf("export query failed: %w", err)
	}

	rows := make([]models.SubscriptionRow, len(rawRows))
	for i, rr := range rawRows {
		rows[i] = models.SubscriptionRow{
			OrderID:         rr.OrderID,
			TransactionCode: rr.TransactionCode,
			BusinessDate:    rr.BusinessDate,
			CustomerName:    rr.CustomerName,
			CIF:             rr.CIF,
			SID:             rr.SID,
			ProductName:     rr.ProductName,
			ProductCode:     rr.ProductCode,
			ChannelType:     rr.ChannelType,
			Units:           rr.Units,
			NAVPerUnit:      rr.NAVPerUnit,
			GrossAmount:     rr.GrossAmount,
			FeeAmount:       rr.FeeAmount,
			StampDuty:       rr.StampDuty,
			NetAmount:       rr.NetAmount,
			LifecycleStatus: rr.LifecycleStatus,
			SettlementDate:  rr.SettlementDate,
		}
	}
	return rows, nil
}

// GetFunds returns all active funds for filter dropdown
func (r *SubscriptionRepository) GetFunds() ([]models.FundOption, error) {
	var funds []models.FundOption
	err := r.db.Table("product").
		Select("product_id as id, product_code, product_name").
		Where("status = ?", "ACTIVE").
		Order("product_name").
		Scan(&funds).Error
	return funds, err
}

// GetChannels returns distinct channel types
func (r *SubscriptionRepository) GetChannels() ([]models.ChannelOption, error) {
	var channels []models.ChannelOption
	err := r.db.Table("distribution_network").
		Select("DISTINCT channel_type").
		Order("channel_type").
		Scan(&channels).Error
	return channels, err
}
