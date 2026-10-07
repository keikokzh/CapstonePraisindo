// Package models defines database entities aligned with Praisindo IMS 2026
// Data Model v2. Fields use NUMERIC types via shopspring/decimal for financial
// precision — no float for money/NAV/units.
package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// Product — E1.1 from Data Model v2
// Produk reksa dana/instrumen yang dikelola
type Product struct {
	ID            uint      `gorm:"primaryKey;column:product_id" json:"product_id"`
	ProductCode   string    `gorm:"size:20;uniqueIndex;column:product_code" json:"product_code"`
	ProductName   string    `gorm:"size:150;column:product_name" json:"product_name"`
	ProductType   string    `gorm:"size:30;column:product_type" json:"product_type"` // Equity/Fixed Income/Money Market/Balanced
	Status        string    `gorm:"size:20;column:status;default:Active" json:"status"`
	ISINCode      string    `gorm:"size:20;column:isin_code" json:"isin_code"`
	InceptionDate time.Time `gorm:"column:inception_date" json:"inception_date"`
	Currency      string    `gorm:"size:3;column:currency;default:IDR" json:"currency"`
}

func (Product) TableName() string { return "product" }

// ProductNAV — E1.2 from Data Model v2
// Histori NAV per unit, harian per produk
type ProductNAV struct {
	ID               uint            `gorm:"primaryKey;column:nav_id" json:"nav_id"`
	ProductID        uint            `gorm:"column:product_id;index" json:"product_id"`
	NAVDate          time.Time       `gorm:"column:nav_date;type:date" json:"nav_date"`
	NAVPerUnit       decimal.Decimal `gorm:"column:nav_per_unit;type:numeric(18,4)" json:"nav_per_unit"`
	UnitsOutstanding decimal.Decimal `gorm:"column:units_outstanding;type:numeric(18,4)" json:"units_outstanding"`
	AUM              decimal.Decimal `gorm:"column:aum;type:numeric(18,2)" json:"aum"`

	Product Product `gorm:"foreignKey:ProductID;references:ID" json:"-"`
}

func (ProductNAV) TableName() string { return "product_nav" }

// Customer — E2.1 from Data Model v2
type Customer struct {
	ID           uint      `gorm:"primaryKey;autoIncrement;column:customer_id" json:"customer_id"`
	CIF          string    `gorm:"size:20;uniqueIndex;column:cif" json:"cif"`
	CustomerName string    `gorm:"size:150;column:customer_name" json:"customer_name"`
	CustomerType string    `gorm:"size:20;column:customer_type" json:"customer_type"` // Individu/Korporasi
	KYCStatus    string    `gorm:"size:20;column:kyc_status;default:Verified" json:"kyc_status"`
	RegisteredAt time.Time `gorm:"column:registered_at" json:"registered_at"`
}

func (Customer) TableName() string { return "customer" }

// InvestorAccount — E2.2 from Data Model v2
// Rekening investor per produk, dengan SID/IFUA dari KSEI
type InvestorAccount struct {
	ID        uint   `gorm:"primaryKey;column:account_id" json:"account_id"`
	CIF       string `gorm:"size:20;column:cif;index" json:"cif"`
	ProductID uint   `gorm:"column:product_id;index" json:"product_id"`
	SID       string `gorm:"size:30;column:sid" json:"sid"`
	IFUA      string `gorm:"size:30;column:ifua" json:"ifua"`
	Status    string `gorm:"size:20;column:status;default:Active" json:"status"`

	Customer Customer `gorm:"foreignKey:CIF;references:CIF" json:"-"`
	Product  Product  `gorm:"foreignKey:ProductID;references:ID" json:"-"`
}

func (InvestorAccount) TableName() string { return "investor_account" }

// SellingAgent — E2.4 from Data Model v2
type SellingAgent struct {
	ID        uint   `gorm:"primaryKey;column:agent_id" json:"agent_id"`
	AgentCode string `gorm:"size:20;uniqueIndex;column:agent_code" json:"agent_code"`
	AgentName string `gorm:"size:150;column:agent_name" json:"agent_name"`
	Region    string `gorm:"size:60;column:region" json:"region"`
	LicenseNo string `gorm:"size:40;column:license_no" json:"license_no"`
	Status    string `gorm:"size:20;column:status;default:Active" json:"status"`
}

func (SellingAgent) TableName() string { return "selling_agent" }

// DistributionNetwork — E2.5 from Data Model v2
// Jalur distribusi/channel tempat agent beroperasi
type DistributionNetwork struct {
	ID          uint   `gorm:"primaryKey;column:network_id" json:"network_id"`
	AgentID     uint   `gorm:"column:agent_id;index" json:"agent_id"`
	ChannelType string `gorm:"size:60;column:channel_type" json:"channel_type"` // Direct/APERD Bank/APERD Sekuritas/Digital
	ParentGroup string `gorm:"size:100;column:parent_group" json:"parent_group"`

	Agent SellingAgent `gorm:"foreignKey:AgentID;references:ID" json:"-"`
}

func (DistributionNetwork) TableName() string { return "distribution_network" }

// OrderTxn — E3.1 from Data Model v2
// Order transaksi inti — satu baris per transaksi
// Untuk TRX-01, kita filter order_type = 'SUBSCRIPTION'
type OrderTxn struct {
	ID              uint            `gorm:"primaryKey;column:order_id" json:"order_id"`
	TransactionCode string          `gorm:"size:30;uniqueIndex;column:transaction_code" json:"transaction_code"` // Format: SUByyMMdd-NNNN
	BusinessDate    time.Time       `gorm:"column:business_date;type:date;index" json:"business_date"`
	OrderDate       time.Time       `gorm:"column:order_date" json:"order_date"`
	ProductID       uint            `gorm:"column:product_id;index" json:"product_id"`
	CIF             string          `gorm:"size:20;column:cif;index" json:"cif"`
	AgentID         *uint           `gorm:"column:agent_id" json:"agent_id"`
	OrderType       string          `gorm:"size:20;column:order_type" json:"order_type"` // SUBSCRIPTION/REDEMPTION/SWITCHING/TRANSFER
	GrossAmount     decimal.Decimal `gorm:"column:gross_amount;type:numeric(18,2)" json:"gross_amount"`
	FeeAmount       decimal.Decimal `gorm:"column:fee_amount;type:numeric(18,2)" json:"fee_amount"`
	StampDuty       decimal.Decimal `gorm:"column:stamp_duty;type:numeric(10,2)" json:"stamp_duty"`
	NetAmount       decimal.Decimal `gorm:"column:net_amount;type:numeric(18,2)" json:"net_amount"`
	Units           decimal.Decimal `gorm:"column:units;type:numeric(18,4)" json:"units"`
	LifecycleStatus string          `gorm:"size:30;column:lifecycle_status;index" json:"lifecycle_status"` // PENDING_FUND/PENDING_NAV/PENDING_SETTLEMENT/SETTLED/EXCEPTION/CLOSED
	SettlementDate  *time.Time      `gorm:"column:settlement_date;type:date" json:"settlement_date"`
	NAVPerUnit      decimal.Decimal `gorm:"column:nav_per_unit;type:numeric(18,4)" json:"nav_per_unit"` // Snapshot NAV at transaction time

	// Relationships
	Product  Product       `gorm:"foreignKey:ProductID;references:ID" json:"product"`
	Customer Customer      `gorm:"foreignKey:CIF;references:CIF" json:"customer"`
	Agent    *SellingAgent  `gorm:"foreignKey:AgentID;references:ID" json:"agent"`
}

func (OrderTxn) TableName() string { return "order_txn" }
