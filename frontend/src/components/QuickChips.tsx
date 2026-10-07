import React from 'react';
import { TabCounts } from '../types';

interface QuickChipsProps {
  activeTab: string;
  tabCounts: TabCounts;
  totalFilteredRecords: number;
  onTabChange: (tab: string) => void;
}

export const QuickChips: React.FC<QuickChipsProps> = ({
  activeTab,
  tabCounts,
  totalFilteredRecords,
  onTabChange,
}) => {
  return (
    <div className="quick-row" aria-label="Status Quick Filter">
      <div className="quick-chips" id="quickChips">
        <button
          type="button"
          className={`quick ${activeTab === 'ALL' ? 'active' : ''}`}
          onClick={() => onTabChange('ALL')}
        >
          All (<span id="qcAll">{tabCounts.all}</span>)
        </button>
        <button
          type="button"
          className={`quick ${activeTab === 'SETTLED' ? 'active' : ''}`}
          onClick={() => onTabChange('SETTLED')}
        >
          Settled (<span id="qcSettled">{tabCounts.settled}</span>)
        </button>
        <button
          type="button"
          className={`quick ${activeTab === 'PENDING' ? 'active' : ''}`}
          onClick={() => onTabChange('PENDING')}
        >
          Pending (<span id="qcPending">{tabCounts.pending}</span>)
        </button>
        <button
          type="button"
          className={`quick ${activeTab === 'EXCEPTION' ? 'active' : ''}`}
          onClick={() => onTabChange('EXCEPTION')}
        >
          Exception (<span id="qcException">{tabCounts.exception}</span>)
        </button>
        <button
          type="button"
          className={`quick ${activeTab === 'CLOSED' ? 'active' : ''}`}
          onClick={() => onTabChange('CLOSED')}
        >
          Closed (<span id="qcClosed">{tabCounts.closed}</span>)
        </button>
      </div>

      <div className="quick-actions">
        <span className="muted" id="resultCount">
          {totalFilteredRecords} records
        </span>
      </div>
    </div>
  );
};
