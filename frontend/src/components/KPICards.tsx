import React from 'react';
import { KPISummary } from '../types';

interface KPICardsProps {
  kpi: KPISummary;
}

export function formatIDR(val: number | string): string {
  const n = typeof val === 'string' ? parseFloat(val) : val;
  if (isNaN(n)) return 'Rp 0';
  return 'Rp ' + Math.round(n).toLocaleString('id-ID');
}

export function formatUnits(val: number | string): string {
  const n = typeof val === 'string' ? parseFloat(val) : val;
  if (isNaN(n)) return '0';
  return n.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

export const KPICards: React.FC<KPICardsProps> = ({ kpi }) => {
  const pendingCount = Number(kpi.pending_count || 0);

  return (
    <section className="kpi-row" id="kpiRow" aria-label="Key Performance Indicators">
      <div className="kpi blue">
        <div className="kl">Total Subscription (Net)</div>
        <div className="kv tabular-nums">{formatIDR(kpi.total_net_subscription)}</div>
        <div className="kf">Periode terpilih</div>
      </div>

      <div className="kpi emerald">
        <div className="kl">Total Unit Terbit</div>
        <div className="kv tabular-nums">{formatUnits(kpi.total_units)}</div>
        <div className="kf">Unit</div>
      </div>

      <div className="kpi">
        <div className="kl">Total Transaksi</div>
        <div className="kv tabular-nums">{kpi.total_transactions}</div>
        <div className="kf">Order subscription</div>
      </div>

      <div className="kpi gold">
        <div className="kl">Avg Ticket Size</div>
        <div className="kv tabular-nums">{formatIDR(kpi.avg_ticket_size)}</div>
        <div className="kf">Per order</div>
      </div>

      <div className={`kpi ${pendingCount > 0 ? 'rose' : 'emerald'}`}>
        <div className="kl">Pending Settlement</div>
        <div className="kv tabular-nums">{pendingCount}</div>
        <div className="kf">PENDING_FUND / NAV / SETTLEMENT</div>
      </div>
    </section>
  );
};
