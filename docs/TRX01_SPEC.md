# TRX-01: Spesifikasi Subscription per Produk Report

## Ruang Lingkup
Laporan rincian order subscription per produk reksa dana — unit, NAV, biaya, dan status settlement.

## Pemetaan Kolom → Data Model (ORDER_TXN + JOINs)

| Kolom UI           | Sumber DB                                         | Tipe DB          |
|--------------------|----------------------------------------------------|------------------|
| Transaction ID     | order_txn.order_id (format SUByyMMdd-NNNN)        | UUID → formatted |
| Trade Date         | order_txn.business_date                           | DATE             |
| Customer           | customer.customer_name (JOIN via cif)             | VARCHAR(150)     |
| SID                | investor_account.sid (JOIN via cif+product_id)    | VARCHAR(30)      |
| Fund               | product.product_name (JOIN via product_id)        | VARCHAR(150)     |
| Channel            | selling_agent → distribution_network.channel_type | ENUM             |
| Units              | order_txn.units                                   | NUMERIC(18,4)    |
| NAV/Unit           | product_nav.nav_per_unit (JOIN product+date)      | NUMERIC(18,4)    |
| Gross Amount       | order_txn.gross_amount                            | NUMERIC(18,2)    |
| Fee                | order_txn.fee_amount (snapshot BR-RPT-08)         | NUMERIC(18,2)    |
| Stamp Duty         | order_txn.stamp_duty                              | NUMERIC(10,2)    |
| Net Amount         | order_txn.net_amount (= gross - fee - stamp_duty) | NUMERIC(18,2)    |
| Status             | order_txn.lifecycle_status                        | ENUM             |
| Settlement Date    | order_txn.settlement_date                         | DATE nullable    |

## Perbedaan Rumus Penting

- **Mockup**: net = gross − fee (tanpa stamp duty)
- **Data model v2**: net = gross − fee − stamp_duty
- **Keputusan**: Ikuti data model. Stamp duty Rp10.000 jika gross > Rp10.000.000.
  ASUMSI DEMO — kebijakan stamp duty belum dikonfirmasi final.

- **Units mockup**: dihitung browser (net/NAV). **Data model**: tersimpan di DB.
  **Keputusan**: Gunakan nilai tersimpan, bukan hitung ulang.

- **Fee**: Snapshot historis (BR-RPT-08 FSD), bukan dihitung ulang.

- **Status lifecycle**: Data model punya PENDING_FUND, PENDING_NAV, PENDING_SETTLEMENT,
  SETTLED, EXCEPTION, CLOSED. Tab "Pending" mencakup semua PENDING_*.

## Kriteria Selesai
1. Filter lengkap: From/To Date, Fund, Status, Channel, Search
2. Tab: All, Settled, Pending, Exception
3. KPI: Total Net, Total Units, Total Txn, Avg Ticket, Pending Count
4. Tabel + footer total (seluruh filter, bukan hanya halaman)
5. Pagination backend, urutan stabil
6. Ekspor CSV, Excel, PDF
7. Migration + seed deterministik
8. Loading, empty, error states
