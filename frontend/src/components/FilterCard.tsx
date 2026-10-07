import React from 'react';
import { RotateCcw } from 'lucide-react';
import { FundOption, ChannelOption } from '../types';

interface FilterCardProps {
  fromDate: string;
  toDate: string;
  fundId: string;
  status: string;
  channel: string;
  search: string;
  funds: FundOption[];
  channels: ChannelOption[];
  onFromDateChange: (val: string) => void;
  onToDateChange: (val: string) => void;
  onFundChange: (val: string) => void;
  onStatusChange: (val: string) => void;
  onChannelChange: (val: string) => void;
  onSearchChange: (val: string) => void;
  onApply: () => void;
  onReset: () => void;
  isLoading?: boolean;
}

export const FilterCard: React.FC<FilterCardProps> = ({
  fromDate,
  toDate,
  fundId,
  status,
  channel,
  search,
  funds,
  channels,
  onFromDateChange,
  onToDateChange,
  onFundChange,
  onStatusChange,
  onChannelChange,
  onSearchChange,
  onApply,
  onReset,
  isLoading,
}) => {
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onApply();
  };

  const isDateInvalid = fromDate && toDate && toDate < fromDate;

  return (
    <section className="filter-card" aria-label="Filter Parameters">
      <form onSubmit={handleSubmit} className="filter-row">
        <div className="field">
          <label htmlFor="pFrom">From Date</label>
          <input
            type="date"
            className="form-input"
            id="pFrom"
            value={fromDate}
            onChange={e => onFromDateChange(e.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="pTo">To Date</label>
          <input
            type="date"
            className="form-input"
            id="pTo"
            value={toDate}
            onChange={e => onToDateChange(e.target.value)}
          />
          {isDateInvalid && (
            <span style={{ color: 'var(--accent-rose)', fontSize: '9px', position: 'absolute' }}>
              To Date &lt; From Date
            </span>
          )}
        </div>

        <div className="field">
          <label htmlFor="pFund">Fund</label>
          <select
            className="form-select"
            id="pFund"
            value={fundId}
            onChange={e => onFundChange(e.target.value)}
          >
            <option value="">All Funds</option>
            {funds.map(f => (
              <option key={f.id} value={String(f.id)}>
                {f.product_name}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="pStatus">Status</label>
          <select
            className="form-select"
            id="pStatus"
            value={status}
            onChange={e => onStatusChange(e.target.value)}
          >
            <option value="">All Status</option>
            <option value="PENDING_FUND">PENDING_FUND</option>
            <option value="CLOSED">CLOSED</option>
            <option value="PENDING_NAV">PENDING_NAV</option>
            <option value="PENDING_SETTLEMENT">PENDING_SETTLEMENT</option>
            <option value="SETTLED">SETTLED</option>
            <option value="EXCEPTION">EXCEPTION</option>
          </select>
        </div>

        <div className="field">
          <label htmlFor="pChannel">Channel</label>
          <select
            className="form-select"
            id="pChannel"
            value={channel}
            onChange={e => onChannelChange(e.target.value)}
          >
            <option value="">All Channels</option>
            {channels.map((c, idx) => (
              <option key={idx} value={c.channel_type}>
                {c.channel_type}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="pSearch">Search</label>
          <input
            type="text"
            className="form-input"
            id="pSearch"
            placeholder="Transaction ID / Customer / SID"
            value={search}
            onChange={e => onSearchChange(e.target.value)}
          />
        </div>

        <button
          type="button"
          className="btn btn-outline"
          onClick={onReset}
          title="Reset filter"
          disabled={isLoading}
        >
          <RotateCcw />
        </button>

        <button
          type="submit"
          className="btn btn-primary"
          disabled={isLoading || Boolean(isDateInvalid)}
        >
          {isLoading ? 'Loading...' : 'Apply'}
        </button>
      </form>
    </section>
  );
};
