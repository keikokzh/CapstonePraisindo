# Progress TRX-01 — 7 Oktober 2026

Status: Implementasi TRX-01 Subscription per Produk selesai dan terverifikasi penuh terhadap PostgreSQL Neon (`urs2026_v2`). Siap commit dan push ke branch `raiyan/setup-report`.

## 1. Implementasi & Fitur Tersedia

- **Backend (Go/Gin/GORM)**:
  - Arsitektur berlapis: config, models/dto, repository, services, handlers.
  - Membaca database PostgreSQL Neon `urs2026_v2` secara langsung melalui `DATABASE_URL_V2`.
  - Endpoint: `/api/health`, `/api/v1/funds`, `/api/v1/channels`, `/api/v1/reports/subscription-by-product`, dan `/api/v1/reports/subscription-by-product/export`.
  - Perhitungan finansial presisi dengan `shopspring/decimal`.
  - Agregasi KPI dan Totals dihitung melintasi seluruh data hasil filter (bukan hanya halaman aktif).
  - Ekspor CSV (dengan UTF-8 BOM), Excel XLSX, dan PDF landscape (dengan header tabel berulang di setiap halaman).
  - Filter lengkap: Tanggal (From/To), Fund (UUID), Channel, Status (termasuk CLOSED & PENDING_FUND), Tab Status (ALL, SETTLED, PENDING, EXCEPTION, CLOSED), dan Pencarian multi-kolom.
- **Frontend (React/TypeScript/Vite)**:
  - Antarmuka visual 100% mengikuti spesifikasi mockup Pak Hazy (Dark/Light mode, font Inter & Space Grotesk).
  - Tanpa mode demo / tanpa generator data lokal. Kegagalan API menampilkan banner error informatif.
  - Penanganan race condition pada request filter dengan `AbortController` dan `requestId.current`.
  - Dukungan routing `#subscription` dan `#subscription-by-product`.
  - Filter tanggal default: 2026-08-01 s/d 2026-10-31 (mencakup data sample V2 September–Oktober).
- **Keamanan & Migrasi**:
  - Seluruh file `.env` diabaikan oleh Git. Hanya `.env.example` dengan placeholder yang dilacak.
  - Database lama `neondb` dan runner migrasi lama tidak disentuh.
  - Runner `cmd/migrate_v2` terkunci dengan manifest V2 resmi (`00`–`13`), advisory lock, dan pengecekan nama database `urs2026_v2`.

## 2. Bukti Pengujian Aktual

- `npm run build`: **PASS** (Kompilasi TypeScript `tsc` dan bundling Vite tanpa error).
- `go test -count=1 ./...`: **PASS** (100% unit tests models, handlers, repository dry-run, migration manifest, dan export services lulus).
- `go vet ./...`: **PASS** (Zero lint/vet warnings).
- **Hasil Aktual dari Neon `urs2026_v2`**:
  - Total records: **10 transaksi**
  - Total Net Subscription: **Rp 2.193.595.000**
  - Total Units: **1.786.847,56**
  - Average Ticket Size: **Rp 219.359.500**
  - Pending Count: **3**
  - Rincian Tab Status:
    - `All`: 10
    - `Settled`: 6
    - `Pending`: 3 (`PENDING_FUND`: 2, `PENDING_SETTLEMENT`: 1)
    - `Closed`: 1
    - `Exception`: 0
- **Verifikasi Ekspor Aktual**:
  - CSV (`format=csv`): HTTP 200, validasi UTF-8 BOM (`\xEF\xBB\xBF`), header lengkap, 10 baris data.
  - Excel (`format=xlsx`): HTTP 200, ukuran 7.637 bytes, format spreadsheet valid.
  - PDF (`format=pdf`): HTTP 200, ukuran 4.523 bytes, magic bytes `%PDF-1.3`, header berulang pada multi-page.
- **Verifikasi UI**:
  - Frontend aktif pada `http://localhost:5173`.
  - Reverse proxy Vite ke `:8080` merespons HTTP 200 untuk seluruh API data dan ekspor.

## 3. Gap & Risiko yang Masih Terbuka (Perlu Diskusi Tim/Bisnis)

1. **Business Date Header**: Sumber tanggal operasional harian belum tersedia di database V2; header menampilkan *"Business Date belum tersedia"*.
2. **Makna Bisnis Status CLOSED**: Data sample V2 memuat 1 transaksi bertatus `CLOSED`. Perilaku bisnis status ini (apakah dapat di-reopen atau setara arsip) perlu konfirmasi lebih lanjut.
3. **Kardinalitas Join**: Relasi `investor_account` (berdasarkan CIF + Product + status ACTIVE) dan relasi agen ke `distribution_network` menggunakan asumsi terbaik saat ini; perlu validasi model operasional produksi.
4. **Bea Meterai**: Simulasi bea meterai masih berupa model prototipe dan belum tervalidasi secara legal/kepatuhan.

## 4. Panduan Handoff untuk Keiko & Jhonata

Lihat [README.md](../README.md) dan [docs/HANDOFF.md](HANDOFF.md) untuk panduan kolaborasi menggunakan database bersama Neon.
- Database bersama `urs2026_v2` sudah siap dan terisi baseline data.
- **PENTING**: Jangan menjalankan ulang perintah migrasi atau seed ke Neon tanpa koordinasi. Cukup jalankan server backend dan frontend lokal Anda.
