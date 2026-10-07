# Panduan Handoff Tim (Raiyan, Keiko, Jhonata)

Dokumen ini ditujukan untuk mempermudah Keiko dan Jhonata dalam melanjutkan pengembangan modul IMS 2026 URS Reporting, khususnya setelah penyelesaian laporan TRX-01 (Subscription per Produk) menggunakan PostgreSQL V2 di Neon.

---

## 1. Arsitektur & Database Bersama (Neon PostgreSQL)

Untuk pengembangan bersama, kita menggunakan database **`urs2026_v2`** yang di-host di Neon:
- Database ini telah diinisialisasi menggunakan baseline resmi PostgreSQL V2 Pak Hazy (`00_extensions_and_types.sql` sampai `13_sample_data.sql`).
- Semua tabel menggunakan Primary Key **UUID**, 31 tipe PostgreSQL ENUM bawaan, dan relasi data terstruktur.
- **PENTING**: Database bersama ini **sudah siap pakai**. Jangan menjalankan skrip migrasi, AutoMigrate, atau script seed lagi ke database ini.

---

## 2. Cara Menjalankan Project di Mesin Masing-Masing

### A. Clone & Setup Frontend
```bash
cd frontend
npm ci
```

### B. Setup Backend & Environment
1. Masuk ke folder backend:
   ```bash
   cd backend
   ```
2. Buat file `.env` lokal berdasarkan `.env.example`:
   ```bash
   cp .env.example .env
   ```
3. Buka `backend/.env` di editor Anda dan isi nilai `DATABASE_URL_V2`:
   ```env
   DATABASE_URL_V2=postgresql://<username>:<password>@<neon-host>/urs2026_v2?sslmode=require
   SERVER_PORT=8080
   FRONTEND_URL=http://localhost:5173
   ```
   > ⚠️ **PERINGATAN KEAMANAN**: File `.env` sudah diatur dalam `.gitignore`. Jangan pernah melakukan git commit atau membagikan connection string ke repositori publik!

### C. Menjalankan Aplikasi
1. **Jalankan Backend**:
   ```bash
   cd backend
   go run cmd/server/main.go
   # Server akan aktif di http://localhost:8080
   ```
2. **Jalankan Frontend (di terminal terpisah)**:
   ```bash
   cd frontend
   npm run dev -- --port 5173
   # Buka browser pada http://localhost:5173
   ```

---

## 3. Komponen Reusable yang Bisa Dipakai untuk Laporan Berikutnya

Untuk laporan selanjutnya (misalnya: **TRX-02 Redemption per Produk**, **TRX-03 Switching**, atau **Monthly Account Statement**), manfaatkan arsitektur yang sudah dibangun:

1. **Layanan Ekspor (`backend/internal/services/export_service.go`)**:
   - Fungsi ekspor CSV (dengan UTF-8 BOM), Excel XLSX, dan PDF landscape multi-halaman dengan pagination dan repeating header.
2. **Komponen UI Modular (`frontend/src/components/`)**:
   - `KPICards`: Menampilkan metrik agregat.
   - `FilterCard`: Template filter rentang tanggal, produk, status, channel, dan search input.
   - `QuickChips`: Filter chip status cepat dengan badge counter reaktif.
   - `ReportTable`: Tabel data dengan sorting, avatar inisial, badge status, pagination, dan footer totals.
   - `Topbar`: Breadcrumbs dan toggle Light/Dark mode.
3. **Pencegahan Race Condition**:
   - Di `SubscriptionReportPage.tsx`, pattern `AbortController` + `requestId.current` memastikan pergantian filter cepat tidak menghasilkan stale state. Gunakan pattern yang sama untuk halaman laporan baru.

---

## 4. Status Pengujian & Batasan Saat Ini

- **Tes Otomatis**:
  - `go test ./...` dan `go vet ./...` di backend: **PASS 100%**.
  - `npm run build` di frontend: **PASS 100%** (zero type error).
- **Hasil Data Baseline Neon saat ini**:
  - Terdapat 10 transaksi subscription sample:
    - 6 SETTLED
    - 3 PENDING (2 PENDING_FUND, 1 PENDING_SETTLEMENT)
    - 1 CLOSED
    - 0 EXCEPTION
  - Total Net: Rp 2.193.595.000
  - Total Units: 1.786.847,56
- **Batasan Terbuka**:
  - Business Date header saat ini menampilkan label *"Business Date belum tersedia"* karena belum ada sumber operasional global di database.
  - Jika ada pertanyaan atau kebutuhan perubahan skema, diskusikan terlebih dahulu sebelum mengubah database bersama.
