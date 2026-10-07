import React from 'react';
import {
  Gauge,
  Package,
  CirclePlus,
  CircleMinus,
  Users,
  UserPlus,
  Briefcase,
  Network,
  BarChart3,
  HandCoins,
  List,
  Repeat,
  ArrowLeftRight,
  Gift,
  Banknote,
  Percent,
  CheckCircle2,
  Activity,
  Building2,
  MailCheck,
  ShieldAlert,
  AlertOctagon,
  SearchCheck,
  FileWarning,
  Landmark,
  FileSpreadsheet,
  PrinterCheck,
  CalendarCheck2,
  Ban,
  TrendingUp,
  Settings,
} from 'lucide-react';

interface SidebarProps {
  currentHash: string;
}

export const Sidebar: React.FC<SidebarProps> = ({ currentHash }) => {
  const getNavClass = (hash: string) => {
    return `nav-item ${currentHash === hash ? 'active' : ''}`;
  };
  const disabledProps = { href: '#', style: { opacity: 0.5, cursor: 'not-allowed' }, onClick: (e: any) => e.preventDefault() };
  return (
    <aside className="sidebar" aria-label="Unit Registry System navigation">
      <div className="sb-brand">
        <div className="sb-logo">I</div>
        <div>
          <div className="sb-name">IMS 2026</div>
          <div className="sb-sub">UNIT REGISTRY SYSTEM</div>
        </div>
      </div>
      <nav className="sb-nav">
        <div className="nav-group">Overview</div>
        <a className={getNavClass('#overview')} {...disabledProps}>
          <Gauge /> Executive Overview
        </a>

        <div className="nav-group">Product Registry</div>
        <a className={getNavClass('#product-master')} {...disabledProps}>
          <Package /> Product Master
        </a>
        <a className={getNavClass('#product-setup')} {...disabledProps}>
          <CirclePlus /> Product Setup
        </a>

        <div className="nav-group">Customer Registry</div>
        <a className={getNavClass('#customer-master')} {...disabledProps}>
          <Users /> Customer Master
        </a>
        <a className={getNavClass('#customer-onboarding')} {...disabledProps}>
          <UserPlus /> Onboarding Workbench
        </a>

        <div className="nav-group">Sales &amp; Distribution</div>
        <a className={getNavClass('#sales-master')} {...disabledProps}>
          <Briefcase /> Sales Master
        </a>
        <a className={getNavClass('#distribution-tree')} {...disabledProps}>
          <Network /> Sales Distribution Tree
        </a>
        <a className={getNavClass('#sales-performance')} {...disabledProps}>
          <BarChart3 /> Sales Performance by Channel/APERD
        </a>
        <a className={getNavClass('#commission-fee')} {...disabledProps}>
          <HandCoins /> Commission/Fee Distribution Report
        </a>

        <div className="nav-group">Transaction Management</div>
        <a className={getNavClass('#transaction-blotter')} {...disabledProps}>
          <List /> Transaction Blotter
        </a>
        <a className={getNavClass('#subscription')} href="#subscription">
          <CirclePlus /> Subscription
        </a>
        <a className={getNavClass('#redemption')} {...disabledProps}>
          <CircleMinus /> Redemption
        </a>
        <a className={getNavClass('#switching')} {...disabledProps}>
          <Repeat /> Switching
        </a>
        <a className={getNavClass('#asset-transfer')} {...disabledProps}>
          <ArrowLeftRight /> Asset Transfer
        </a>
        <a className={getNavClass('#distribution')} {...disabledProps}>
          <Gift /> Distribution
        </a>

        <div className="nav-group">Cash, NAV &amp; Settlement</div>
        <a className={getNavClass('#payment-matching')} {...disabledProps}>
          <Banknote /> Payment Matching
        </a>
        <a className={getNavClass('#nav-allocation')} {...disabledProps}>
          <Percent /> NAV Allocation
        </a>
        <a className={getNavClass('#settlement-monitor')} {...disabledProps}>
          <CheckCircle2 /> Settlement Monitor
        </a>

        <div className="nav-group">External Processing</div>
        <a className={getNavClass('#external-monitor')} {...disabledProps}>
          <Activity /> External Monitor
        </a>
        <a className={getNavClass('#sinvest-monitor')} {...disabledProps}>
          <Building2 /> S-INVEST Monitor
        </a>
        <a className={getNavClass('#confirmation-monitor')} {...disabledProps}>
          <MailCheck /> Confirmation Monitor
        </a>

        <div className="nav-group">Compliance &amp; AML</div>
        <a className={getNavClass('#compliance-dashboard')} {...disabledProps}>
          <ShieldAlert /> Compliance Dashboard
        </a>
        <a className={getNavClass('#aml-alert-queue')} {...disabledProps}>
          <AlertOctagon /> AML/CFT Alert Queue
        </a>
        <a className={getNavClass('#aml-alert-summary')} {...disabledProps}>
          <ShieldAlert /> AML/CFT Alert Summary Report
        </a>
        <a className={getNavClass('#sanctions-pep')} {...disabledProps}>
          <SearchCheck /> Sanctions &amp; PEP Screening
        </a>
        <a className={getNavClass('#suspicious-transaction')} {...disabledProps}>
          <FileWarning /> Suspicious Transaction Report (LTKM)
        </a>
        <a className={getNavClass('#ojk-periodic')} {...disabledProps}>
          <Landmark /> OJK Periodic Report (Laporan Bulanan)
        </a>

        <div className="nav-group">Statements &amp; Documents</div>
        <a className={getNavClass('#account-statement')} {...disabledProps}>
          <FileSpreadsheet /> Account Statement
        </a>
        <a className={getNavClass('#transaction-confirmation')} {...disabledProps}>
          <PrinterCheck /> Transaction Confirmation Report
        </a>
        <a className={getNavClass('#daily-transaction')} {...disabledProps}>
          <CalendarCheck2 /> Daily Transaction Summary Report
        </a>
        <a className={getNavClass('#cancelled-rejected')} {...disabledProps}>
          <Ban /> Cancelled/Rejected Transaction Report
        </a>
        <a className={getNavClass('#subscription-by-product')} href="#subscription-by-product" aria-current={currentHash === '#subscription-by-product' ? "page" : undefined}>
          <CirclePlus /> Subscription per Produk Report
        </a>
        <a className={getNavClass('#redemption-by-product')} {...disabledProps}>
          <CircleMinus /> Redemption per Produk Report
        </a>
        <a className={getNavClass('#switching-report')} {...disabledProps}>
          <Repeat /> Switching Report
        </a>
        <a className={getNavClass('#asset-unit-transfer')} {...disabledProps}>
          <ArrowLeftRight /> Asset/Unit Transfer Report
        </a>
        <a className={getNavClass('#unit-outstanding')} {...disabledProps}>
          <TrendingUp /> Unit Outstanding &amp; AUM Movement Report
        </a>
        <a className={getNavClass('#nav-allocation-report')} {...disabledProps}>
          <Percent /> NAV Allocation Report
        </a>

        <div className="nav-group">Configuration</div>
        <a className={getNavClass('#configuration')} {...disabledProps}>
          <Settings /> Master Configuration
        </a>
      </nav>
    </aside>
  );
};
