import React, { useState, useEffect, useRef } from 'react';
import { Download, FileSpreadsheet, FileDown, Info, CheckCircle2 } from 'lucide-react';
import { KPICards } from '../components/KPICards';
import { FilterCard } from '../components/FilterCard';
import { QuickChips } from '../components/QuickChips';
import { ReportTable } from '../components/ReportTable';
import {
  fetchSubscriptionReport,
  fetchFunds,
  fetchChannels,
  triggerExportDownload
} from '../services/api';
import {
  FilterParams,
  FundOption,
  ChannelOption,
  SubscriptionReportResponse,
} from '../types';

export const SubscriptionReportPage: React.FC = () => {
  // Filter form states
  const [fromDate, setFromDate] = useState('2026-08-01');
  const [toDate, setToDate] = useState('2026-10-31');
  const [fundId, setFundId] = useState('');
  const [status, setStatus] = useState('');
  const [channel, setChannel] = useState('');
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('ALL');


  const [applied, setApplied] = useState<FilterParams>({ from_date: '2026-08-01', to_date: '2026-10-31', tab: 'ALL', page: 1, page_size: 20 });
  const [reloadKey, setReloadKey] = useState(0);
  const requestId = useRef(0);

  // Dropdown options
  const [funds, setFunds] = useState<FundOption[]>([]);
  const [channels, setChannels] = useState<ChannelOption[]>([]);

  // Report data state
  const [reportData, setReportData] = useState<SubscriptionReportResponse>({
    data: [],
    pagination: { page: 1, page_size: 20, total_records: 0, total_pages: 1 },
    kpi: {
      total_net_subscription: 0,
      total_units: 0,
      total_transactions: 0,
      avg_ticket_size: 0,
      pending_count: 0,
    },
    totals: {
      units: 0,
      gross_amount: 0,
      fee_amount: 0,
      stamp_duty: 0,
      net_amount: 0,
    },
    tab_counts: {
      all: 0,
      settled: 0,
      pending: 0,
      exception: 0,
      closed: 0,
    },
  });

  const [isLoading, setIsLoading] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);
  const [isTableExpanded, setIsTableExpanded] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [genTime, setGenTime] = useState<string>('');

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  // Initial load options
  useEffect(() => {
    fetchFunds().then(setFunds).catch(() => {});
    fetchChannels().then(setChannels).catch(() => {});
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const id = ++requestId.current;
    setIsLoading(true);
    setApiError(null);
    fetchSubscriptionReport(applied, controller.signal).then(res => {
      if (id !== requestId.current || controller.signal.aborted) return;
      setReportData(res);
      setGenTime(new Date().toLocaleString('id-ID', {
        dateStyle: 'long', timeStyle: 'short', timeZone: 'Asia/Jakarta',
      }) + ' WIB');
    }).catch(() => {
      if (id !== requestId.current || controller.signal.aborted) return;
      setApiError('Gagal mengambil data dari server. Pastikan backend berjalan dan terhubung ke database.');
    }).finally(() => {
      if (id === requestId.current && !controller.signal.aborted) setIsLoading(false);
    });
    return () => controller.abort();
  }, [applied, reloadKey]);

  const handleApply = () => {
    if (!fromDate || !toDate || toDate < fromDate) {
      showToast('Tanggal wajib diisi dan tanggal akhir tidak boleh sebelum tanggal awal.');
      return;
    }
    setActiveTab('ALL');
    setApplied({ from_date: fromDate, to_date: toDate,
      fund_id: fundId || undefined, status: status || undefined,
      channel: channel || undefined, search: search || undefined,
      tab: 'ALL', page: 1, page_size: 20 });
  };

  const handleReset = () => {
    setFromDate('2026-08-01'); setToDate('2026-10-31');
    setFundId(''); setStatus(''); setChannel(''); setSearch('');
    setActiveTab('ALL');
    setApplied({ from_date: '2026-08-01', to_date: '2026-10-31', tab: 'ALL', page: 1, page_size: 20 });
  };

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    setApplied(prev => ({ ...prev, tab, page: 1 }));
  };

  const handlePageChange = (newPage: number) => {
    setApplied(prev => ({ ...prev, page: newPage }));
  };

  const handleExport = async (format: 'csv' | 'xlsx' | 'pdf') => {
    showToast(`Mempersiapkan ekspor ${format.toUpperCase()}...`);
    try {
      await triggerExportDownload(applied, format);
      showToast(`File ${format.toUpperCase()} berhasil diunduh.`);
    } catch {
      showToast('Ekspor gagal. Coba lagi setelah koneksi server tersedia.');
    }
  };

  return (
    <div className={`page-body ${isTableExpanded ? 'expanded-table' : ''}`}>


      <div className="page-head">
        <div>
          <h1>Report: Subscription per Produk</h1>
          <div className="sub">
            Rincian order subscription per produk reksa dana — unit, NAV, biaya, dan status settlement — untuk monitoring penjualan per produk.
          </div>
        </div>
        <div className="head-actions">
          <button className="btn" onClick={() => setIsTableExpanded(!isTableExpanded)} style={{ marginRight: '16px' }}>
            {isTableExpanded ? 'Kembali ke Normal' : 'Perluas Tabel'}
          </button>
          <button className="btn" onClick={() => handleExport('csv')} disabled={!!apiError || isLoading}>
            <Download /> Export CSV
          </button>
          <button className="btn" onClick={() => handleExport('xlsx')} disabled={!!apiError || isLoading}>
            <FileSpreadsheet /> Export Excel
          </button>
          <button className="btn btn-primary" onClick={() => handleExport('pdf')} disabled={!!apiError || isLoading}>
            <FileDown /> Export PDF
          </button>
        </div>
      </div>

      {apiError && (
        <div style={{ background: '#fee2e2', color: '#991b1b', padding: '12px 16px', borderRadius: '6px', marginBottom: '16px', fontSize: '14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>{apiError}</span>
          <button className="btn btn-primary" onClick={() => setReloadKey(k => k + 1)}>Coba Lagi</button>
        </div>
      )}

      {/* Hide header cards when expanded */}
      {!isTableExpanded && (
        <>
          {/* KPI SUMMARY */}
          {isLoading ? <div role="status">Memuat ringkasan laporan...</div> : !apiError && <KPICards kpi={reportData.kpi} />}

          {/* PARAMETER BAR */}
          <FilterCard
            fromDate={fromDate}
            toDate={toDate}
            fundId={fundId}
            status={status}
            channel={channel}
            search={search}
            funds={funds}
            channels={channels}
            onFromDateChange={setFromDate}
            onToDateChange={setToDate}
            onFundChange={setFundId}
            onStatusChange={setStatus}
            onChannelChange={setChannel}
            onSearchChange={setSearch}
            onApply={handleApply}
            onReset={handleReset}
            isLoading={isLoading}
          />
        </>
      )}

      {/* QUICK CHIPS */}
      <QuickChips
        activeTab={activeTab}
        tabCounts={reportData.tab_counts}
        totalFilteredRecords={isLoading || apiError ? 0 : reportData.pagination.total_records}
        onTabChange={handleTabChange}
      />

      {/* TABLE */}
      <ReportTable
        rows={apiError ? [] : reportData.data}
        totals={reportData.totals}
        pagination={reportData.pagination}
        isLoading={isLoading}
        onPageChange={handlePageChange}
      />

      {/* FOOTER STRIP */}
      <div className="foot-strip">
        <div className="foot-note">
          <Info /> Net Amount = Gross Amount − Fee − Stamp Duty. Status mengikuti lifecycle order: PENDING_NAV → PENDING_SETTLEMENT → SETTLED, atau EXCEPTION bila terjadi kegagalan proses.
        </div>
        <div id="genTime" className="muted">
          Report generated {genTime}
        </div>
      </div>

      {/* TOAST NOTIFICATION */}
      {toastMessage && (
        <div className="toast">
          <CheckCircle2 style={{ width: 16, height: 16, color: 'var(--accent-emerald)' }} />
          <span>{toastMessage}</span>
        </div>
      )}
    </div>
  );
};
