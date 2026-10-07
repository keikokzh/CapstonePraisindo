export interface SubscriptionRow {
  order_id: string;
  transaction_code: string;
  business_date: string;
  customer_name: string;
  cif: string;
  sid: string;
  product_name: string;
  product_code: string;
  channel_type: string;
  units: number | string;
  nav_per_unit: number | string;
  gross_amount: number | string;
  fee_amount: number | string;
  stamp_duty: number | string;
  net_amount: number | string;
  lifecycle_status: string;
  settlement_date: string | null;
}

export interface KPISummary {
  total_net_subscription: number | string;
  total_units: number | string;
  total_transactions: number;
  avg_ticket_size: number | string;
  pending_count: number;
}

export interface TotalsSummary {
  units: number | string;
  gross_amount: number | string;
  fee_amount: number | string;
  stamp_duty: number | string;
  net_amount: number | string;
}

export interface TabCounts {
  all: number;
  settled: number;
  pending: number;
  exception: number;
  closed: number;
}

export interface Pagination {
  page: number;
  page_size: number;
  total_records: number;
  total_pages: number;
}

export interface SubscriptionReportResponse {
  data: SubscriptionRow[];
  pagination: Pagination;
  kpi: KPISummary;
  totals: TotalsSummary;
  tab_counts: TabCounts;
}

export interface FundOption {
  id: string;
  product_code: string;
  product_name: string;
}

export interface ChannelOption {
  channel_type: string;
}

export interface FilterParams {
  from_date: string;
  to_date: string;
  fund_id?: number | string;
  status?: string;
  channel?: string;
  search?: string;
  tab?: string;
  page?: number;
  page_size?: number;
}
