# CapstonePraisindo — IMS 2026 URS Reporting

Modul reporting React/TypeScript/Vite dan Go/Gin/GORM, menggunakan PostgreSQL V2 Pak Hazy.
TRX-01 Subscription per Produk tersedia; Redemption, Switching, dan Monthly Account Statement belum menjadi deliverable selesai.

## Menjalankan project yang sudah memiliki database V2

1. Install dependency frontend dengan `npm ci` dari folder `frontend`.
2. Jika `backend/.env` belum ada, salin `backend/.env.example` ke sana. Isi `DATABASE_URL_V2` secara lokal dengan database `urs2026_v2`. Jangan overwrite `.env` yang sudah ada atau mengirim password ke Git.
3. Dari `backend`: `go run ./cmd/server`.
4. Di terminal lain, dari `frontend`: `npm run dev -- --port 5173`.
5. Buka http://localhost:5173/#subscription-by-product. Health endpoint: http://localhost:8080/api/health.

Tidak perlu menjalankan migration/seed lagi untuk memakai database bersama yang sudah terpasang.
Frontend membaca API, tanpa fallback demo lokal. Data sample di Neon tetap data sintetis, bukan transaksi nasabah produksi.

## Database dan instalasi baru

Baca [DATABASE_V2.md](docs/DATABASE_V2.md) sebelum instalasi. Runner lama `cmd/migrate` dan `cmd/seed` dinonaktifkan.
Runner resmi `cmd/migrate_v2` memakai SQL tertanam di `backend/internal/migration/sql`, sehingga clone tidak membutuhkan folder references yang diabaikan Git.
Docker Compose hanya menyediakan PostgreSQL; tidak memasang V1/seed otomatis dan tidak mengubah volume yang sudah ada. Konfigurasi Docker lama bukan database V2 siap pakai.

## Status laporan

- All mencakup seluruh status; Settled = SETTLED; Pending = PENDING_FUND/PENDING_NAV/PENDING_SETTLEMENT; Exception = EXCEPTION; Closed = CLOSED.
- Counter tab mempertahankan filter tanggal/produk/channel/pencarian, tetapi mengabaikan dropdown status dan tab aktif (perilaku saat ini). Dropdown dan tab aktif bersama-sama membatasi baris/KPI. Karena itu All pada chips bisa berbeda dengan jumlah hasil ketika dropdown status dipilih.
- Closed belum didefinisikan lebih lanjut oleh bisnis; jangan disamakan dengan Settled, pembatalan, atau kegagalan.
- Business Date belum tersedia: sumber tanggal operasional belum disepakati; header tidak mengambil tanggal komputer atau akhir periode laporan.
- Filter awal masih Agustus–Oktober 2026. Sample SQL menggunakan CURRENT_DATE saat instalasi; pilih rentang sesuai data pada database masing-masing.
- CSV/Excel/PDF tersedia. Berhasil mengunduh tidak membuktikan seluruh isi atau layout sudah benar.

## Verifikasi

Dari `backend`: `go test ./...` dan `go vet ./...`.
Dari `frontend`: `npm run build`.
Lihat [PROGRESS.md](docs/PROGRESS.md) untuk bukti aktual dan batas pengujian, serta [SCHEMA_V2_MAPPING.md](docs/SCHEMA_V2_MAPPING.md) untuk gap bisnis.

## Handoff untuk Keiko & Jhonata (Database Bersama Neon)

Panduan detail kolaborasi tim tersedia di [docs/HANDOFF.md](docs/HANDOFF.md).
- **Database Neon Bersama**: Kita menggunakan database `urs2026_v2` di Neon yang sudah terisi baseline skema V2 dan data sample resmi (10 transaksi).
- **Aturan Kolaborasi**: Jangan menjalankan migrasi atau script seed ulang ke Neon. Cukup clone, atur `.env` lokal dengan `DATABASE_URL_V2`, dan jalankan backend serta frontend di mesin masing-masing.
- **Kredensial**: File `.env` sudah diabaikan di `.gitignore`. Gunakan `.env.example` sebagai template lokal dan jangan pernah commit connection string ke Git.
- **Pengembangan Laporan Berikutnya**: Gunakan komponen reusable yang sudah ada di `frontend/src/components/` (`KPICards`, `FilterCard`, `QuickChips`, `ReportTable`) dan layanan ekspor di `backend/internal/services/export_service.go`.

## Berbagi dengan tim

Simpan perubahan ke branch fitur, review, lalu integrasikan ke main. Kredensial diatur lokal oleh masing-masing anggota. Sepakati satu pengelola migration database bersama. File references tidak ikut Git; distribusikan bahan referensi melalui kanal internal yang disepakati.
