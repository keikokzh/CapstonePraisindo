// Package models - DTO types for API request/response
package models

import "github.com/shopspring/decimal"

// SubscriptionFilter represents query parameters for TRX-01 report
type SubscriptionFilter struct {
	FromDate  string  `form:"from_date" binding:"required"`
	ToDate    string  `form:"to_date" binding:"required"`
	FundID    *string `form:"fund_id"`
	Status    string  `form:"status"`
	Channel   string  `form:"channel"`
	Search    string  `form:"search"`
	Tab       string  `form:"tab"` // ALL/SETTLED/PENDING/EXCEPTION/CLOSED
	Page      int     `form:"page"`
	PageSize  int     `form:"page_size"`
	SortBy    string  `form:"sort_by"`
	SortOrder string  `form:"sort_order"` // asc/desc
}

// Defaults sets default values for pagination and sort
func (f *SubscriptionFilter) Defaults() {
	if f.Page <= 0 {
		f.Page = 1
	}
	if f.PageSize <= 0 || f.PageSize > 100 {
		f.PageSize = 20
	}
	if f.Tab == "" {
		f.Tab = "ALL"
	}
	if f.SortBy == "" {
		f.SortBy = "business_date"
	}
	if f.SortOrder == "" {
		f.SortOrder = "desc"
	}
}

// SubscriptionRow represents a single row in the report
type SubscriptionRow struct {
	OrderID         string          `json:"order_id"`
	TransactionCode string          `json:"transaction_code"`
	BusinessDate    string          `json:"business_date"`
	CustomerName    string          `json:"customer_name"`
	CIF             string          `json:"cif"`
	SID             string          `json:"sid"`
	ProductName     string          `json:"product_name"`
	ProductCode     string          `json:"product_code"`
	ChannelType     string          `json:"channel_type"`
	Units           decimal.Decimal `json:"units"`
	NAVPerUnit      decimal.Decimal `json:"nav_per_unit"`
	GrossAmount     decimal.Decimal `json:"gross_amount"`
	FeeAmount       decimal.Decimal `json:"fee_amount"`
	StampDuty       decimal.Decimal `json:"stamp_duty"`
	NetAmount       decimal.Decimal `json:"net_amount"`
	LifecycleStatus string          `json:"lifecycle_status"`
	SettlementDate  *string         `json:"settlement_date"`
}

// KPISummary holds KPI values for the report header
type KPISummary struct {
	TotalNetSubscription decimal.Decimal `json:"total_net_subscription"`
	TotalUnits           decimal.Decimal `json:"total_units"`
	TotalTransactions    int64           `json:"total_transactions"`
	AvgTicketSize        decimal.Decimal `json:"avg_ticket_size"`
	PendingCount         int64           `json:"pending_count"`
}

// TotalsSummary holds footer totals (computed across ALL filtered records, not just current page)
type TotalsSummary struct {
	Units       decimal.Decimal `json:"units"`
	GrossAmount decimal.Decimal `json:"gross_amount"`
	FeeAmount   decimal.Decimal `json:"fee_amount"`
	StampDuty   decimal.Decimal `json:"stamp_duty"`
	NetAmount   decimal.Decimal `json:"net_amount"`
}

// TabCounts holds count per status tab
type TabCounts struct {
	All       int64 `json:"all"`
	Settled   int64 `json:"settled"`
	Pending   int64 `json:"pending"`
	Exception int64 `json:"exception"`
	Closed    int64 `json:"closed"`
}

// Pagination metadata
type Pagination struct {
	Page         int   `json:"page"`
	PageSize     int   `json:"page_size"`
	TotalRecords int64 `json:"total_records"`
	TotalPages   int   `json:"total_pages"`
}

// SubscriptionReportResponse is the complete API response
type SubscriptionReportResponse struct {
	Data       []SubscriptionRow `json:"data"`
	Pagination Pagination        `json:"pagination"`
	KPI        KPISummary        `json:"kpi"`
	Totals     TotalsSummary     `json:"totals"`
	TabCounts  TabCounts         `json:"tab_counts"`
}

// FundOption for filter dropdown
type FundOption struct {
	ID          string `json:"id"`
	ProductCode string `json:"product_code"`
	ProductName string `json:"product_name"`
}

// ChannelOption for filter dropdown
type ChannelOption struct {
	ChannelType string `json:"channel_type"`
}
