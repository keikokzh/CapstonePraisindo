import React from 'react';
import { SubscriptionRow, TotalsSummary, Pagination } from '../types';
import { formatIDR, formatUnits } from './KPICards';

interface ReportTableProps {
  rows: SubscriptionRow[];
  totals: TotalsSummary;
  pagination: Pagination;
  isLoading: boolean;
  onPageChange: (page: number) => void;
}

const FUND_ACCENT: Record<string, { color: string; bg: string; border: string }> = {
  'Praisindo Equity Fund': {
    color: 'var(--accent-blue)',
    bg: 'rgba(37,99,235,0.08)',
    border: 'rgba(37,99,235,0.25)',
  },
  'Praisindo Fixed Income Fund': {
    color: 'var(--accent-emerald)',
    bg: 'rgba(5,150,105,0.08)',
    border: 'rgba(5,150,105,0.25)',
  },
  'Praisindo Money Market Fund': {
    color: 'var(--accent-gold)',
    bg: 'rgba(217,119,6,0.08)',
    border: 'rgba(217,119,6,0.25)',
  },
};

const AVATAR_COLORS = [
  '#2563EB', '#059669', '#7C3AED', '#D97706',
  '#E11D48', '#0EA5E9', '#65A30D', '#DB2777',
];

function getCustomerColor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function getInitials(name: string): string {
  if (!name) return '—';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—';
  try {
    const d = new Date(dateStr + (dateStr.length === 10 ? 'T00:00:00' : ''));
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleDateString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

function getStatusBadgeClass(status: string): string {
  switch (status) {
    case 'SETTLED':
    case 'COMPLETED':
    case 'APPROVED':
      return 'badge-emerald';
    case 'PENDING_NAV':
    case 'PENDING_SETTLEMENT':
    case 'PENDING_FUND':
    case 'PENDING_APPROVAL':
      return 'badge-gold';
    case 'EXCEPTION':
    case 'REJECTED':
      return 'badge-rose';
    default:
      return 'badge-gray';
  }
}

export const ReportTable: React.FC<ReportTableProps> = ({
  rows,
  totals,
  pagination,
  isLoading,
  onPageChange,
}) => {
  const { page, page_size, total_records, total_pages } = pagination;
  const startRecord = total_records > 0 ? (page - 1) * page_size + 1 : 0;
  const endRecord = Math.min(page * page_size, total_records);

  // Generate page numbers
  const maxButtons = 7;
  let startP = Math.max(1, page - 3);
  let endP = Math.min(total_pages, startP + maxButtons - 1);
  if (endP - startP < maxButtons - 1) {
    startP = Math.max(1, endP - maxButtons + 1);
  }
  const pageNumbers: number[] = [];
  for (let p = startP; p <= endP; p++) {
    pageNumbers.push(p);
  }

  return (
    <div className="table-card">
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Transaction ID</th>
              <th>Trade Date</th>
              <th>Customer</th>
              <th>SID</th>
              <th>Fund</th>
              <th>Channel</th>
              <th className="num">Units</th>
              <th className="num">NAV/Unit</th>
              <th className="num">Gross Amount</th>
              <th className="num">Fee</th>
              <th className="num">Net Amount</th>
              <th>Status</th>
              <th>Settlement Date</th>
            </tr>
          </thead>

          <tbody id="tblBody">
            {isLoading ? (
              <tr>
                <td colSpan={13}>
                  <div className="state-container">
                    <div className="spinner" />
                    <span>Memuat data laporan...</span>
                  </div>
                </td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td
                  colSpan={13}
                  style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}
                >
                  Tidak ada data order subscription yang sesuai dengan kriteria filter.
                </td>
              </tr>
            ) : (
              rows.map(r => {
                const fundStyle = FUND_ACCENT[r.product_name] || {
                  color: 'var(--accent-blue)',
                  bg: 'rgba(37,99,235,0.08)',
                  border: 'rgba(37,99,235,0.25)',
                };
                const avaBg = getCustomerColor(r.customer_name);
                const initials = getInitials(r.customer_name);

                return (
                  <tr key={r.order_id || r.transaction_code}>
                    <td className="mono link">{r.transaction_code}</td>
                    <td>{formatDate(r.business_date)}</td>
                    <td>
                      <div className="cust-cell">
                        <div className="cust-ava" style={{ backgroundColor: avaBg }}>
                          {initials}
                        </div>
                        <div>
                          <div className="cust-name" title={r.customer_name}>
                            {r.customer_name}
                          </div>
                          <div className="cust-cif">CIF {r.cif}</div>
                        </div>
                      </div>
                    </td>
                    <td className="mono muted" style={{ fontSize: '10px' }}>
                      {r.sid || '—'}
                    </td>
                    <td>
                      <span
                        className="fund-pill"
                        style={{
                          color: fundStyle.color,
                          backgroundColor: fundStyle.bg,
                          borderColor: fundStyle.border,
                        }}
                      >
                        {r.product_name}
                      </span>
                    </td>
                    <td className="muted" style={{ fontSize: '10.5px' }}>
                      {r.channel_type}
                    </td>
                    <td className="num tabular-nums">{formatUnits(r.units)}</td>
                    <td className="num tabular-nums">{formatUnits(r.nav_per_unit)}</td>
                    <td className="num">{formatIDR(r.gross_amount)}</td>
                    <td className="num muted">{formatIDR(r.fee_amount)}</td>
                    <td className="num" style={{ fontWeight: 700 }}>
                      {formatIDR(r.net_amount)}
                    </td>
                    <td>
                      <span className={`badge ${getStatusBadgeClass(r.lifecycle_status)}`}>
                        {r.lifecycle_status.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td>{formatDate(r.settlement_date)}</td>
                  </tr>
                );
              })
            )}
          </tbody>

          {total_records > 0 && (
            <tfoot id="tblFoot">
              <tr>
                <td colSpan={6}>TOTAL (filtered: {total_records} records)</td>
                <td className="num">{formatUnits(totals.units)}</td>
                <td></td>
                <td className="num">{formatIDR(totals.gross_amount)}</td>
                <td className="num">{formatIDR(totals.fee_amount)}</td>
                <td className="num">{formatIDR(totals.net_amount)}</td>
                <td colSpan={2}></td>
              </tr>
            </tfoot>
          )}
        </table>
      </div>

      <div className="pagination">
        <div className="page-left">
          <span id="pageInfo">
            {total_records > 0
              ? `Showing ${startRecord}–${endRecord} of ${total_records}`
              : 'Showing 0–0 of 0'}
          </span>
        </div>
        <div className="pager" id="pager">
          <button
            type="button"
            className="page-btn"
            disabled={page <= 1}
            onClick={() => onPageChange(page - 1)}
            aria-label="Previous page"
          >
            ‹
          </button>
          {pageNumbers.map(p => (
            <button
              key={p}
              type="button"
              className={`page-btn ${p === page ? 'active' : ''}`}
              onClick={() => onPageChange(p)}
            >
              {p}
            </button>
          ))}
          <button
            type="button"
            className="page-btn"
            disabled={page >= total_pages}
            onClick={() => onPageChange(page + 1)}
            aria-label="Next page"
          >
            ›
          </button>
        </div>
      </div>
    </div>
  );
};
