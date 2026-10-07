import { FilterParams, SubscriptionReportResponse, FundOption, ChannelOption } from '../types';

const API_BASE = '/api/v1';

export async function fetchFunds(): Promise<FundOption[]> {
  const res = await fetch(`${API_BASE}/funds`);
  if (!res.ok) throw new Error('Failed to fetch funds');
  return await res.json();
}

export async function fetchChannels(): Promise<ChannelOption[]> {
  const res = await fetch(`${API_BASE}/channels`);
  if (!res.ok) throw new Error('Failed to fetch channels');
  return await res.json();
}

export async function fetchSubscriptionReport(params: FilterParams, signal?: AbortSignal): Promise<SubscriptionReportResponse> {
  const query = new URLSearchParams();
  query.set('from_date', params.from_date);
  query.set('to_date', params.to_date);
  if (params.fund_id) query.set('fund_id', String(params.fund_id));
  if (params.status) query.set('status', params.status);
  if (params.channel) query.set('channel', params.channel);
  if (params.search) query.set('search', params.search);
  if (params.tab) query.set('tab', params.tab);
  if (params.page) query.set('page', String(params.page));
  if (params.page_size) query.set('page_size', String(params.page_size));

  const res = await fetch(`${API_BASE}/reports/subscription-by-product?${query.toString()}`, { signal });
  if (!res.ok) throw new Error('Failed to fetch report data');
  return await res.json();
}

export function getExportUrl(params: FilterParams, format: 'csv' | 'xlsx' | 'pdf'): string {
  const query = new URLSearchParams();
  query.set('from_date', params.from_date);
  query.set('to_date', params.to_date);
  if (params.fund_id) query.set('fund_id', String(params.fund_id));
  if (params.status) query.set('status', params.status);
  if (params.channel) query.set('channel', params.channel);
  if (params.search) query.set('search', params.search);
  if (params.tab) query.set('tab', params.tab);
  query.set('format', format);
  return `${API_BASE}/reports/subscription-by-product/export?${query.toString()}`;
}

export async function triggerExportDownload(params: FilterParams, format: 'csv' | 'xlsx' | 'pdf'): Promise<boolean> {
  const url = getExportUrl(params, format);
  const res = await fetch(url);
  if (!res.ok) throw new Error('Export failed');
  
  const blob = await res.blob();
  const downloadUrl = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = downloadUrl;
  const contentDisposition = res.headers.get('content-disposition');
  let filename = `subscription_report_${params.from_date}_${params.to_date}.${format}`;
  if (contentDisposition) {
    const match = contentDisposition.match(/filename=(.+)/);
    if (match && match[1]) filename = match[1];
  }
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.URL.revokeObjectURL(downloadUrl);
  return true;
}


