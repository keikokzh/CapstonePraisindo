# Instalasi baseline PostgreSQL V2

## Sumber dan pemisahan

`backend/internal/migration/sql/00_...` sampai `13_sample_data.sql` adalah salinan byte-identik paket Pak Hazy dari `references/Praisindo_URS2026_PostgreSQL_Schema_v2/migrations/`.
File upstream dan migration lama tidak diubah. Salinan di internal/migration/sql adalah sumber eksekusi resmi yang ditanam ke binary dengan go:embed. Jangan mengubah baseline yang sudah diterapkan; penyesuaian berikutnya perlu migration terpisah dan peninjauan tim.
`backend/migrations/` masih menyimpan file historis/campuran, bukan sumber runner aktif. Jangan menjalankan seluruh folder itu atau `run_all.sql` lewat GORM.

## Perintah eksplisit (tidak dijalankan dalam checkpoint perbaikan ini)

Untuk instalasi baru yang sengaja disetujui, jalankan dari backend setelah mengisi DATABASE_URL_V2 di .env:

```sh
go run ./cmd/migrate_v2 --apply
```

Ini memasang 00–12 (termasuk seed konfigurasi upstream pada 12), bukan sample transaksi 13.
Untuk menambahkan sample resmi satu kali pada database pengembangan:

```sh
go run ./cmd/migrate_v2 --apply --include-sample-data
```

Sample menggunakan CURRENT_DATE; tanggal data mengikuti waktu instalasi. Jangan memakai seed 85 transaksi V1.
Tanpa --apply runner berhenti sebelum membaca konfigurasi/koneksi. Runner lama migrate dan seed berhenti tanpa terhubung database.

## Proteksi runner

- Memeriksa SELECT current_database() = urs2026_v2; tidak bergantung pada substring URL.
- Daftar 00–13 eksplisit; run_all.sql, 001_create_tables.sql, dan file lain tidak masuk daftar.
- Satu transaksi untuk seluruh file yang belum diterapkan beserta pencatatan ledger; gagal menyebabkan rollback transaksi itu.
- Advisory transaction lock mencegah dua runner resmi memasang secara bersamaan.
- Menggunakan ledger lama schema_migration_v2; versi yang sudah tercatat tidak diulang. Riwayat harus merupakan awalan berurutan daftar baseline; riwayat asing/berlubang ditolak.
- Database tanpa ledger harus kosong (tabel/view/sequence/enum publik diperiksa). Ledger kosong di samping tabel lama juga ditolak.
- Ledger lama tidak menyimpan checksum; runner tidak bisa membuktikan isi SQL yang pernah diterapkan. Jangan mengubah isi baseline atau menandai migration manual untuk melewati error.
- AutoMigrate sudah tidak dipakai runner. Ledger dibuat dengan SQL eksplisit.

Tidak ada migration, seed, perubahan volume, atau pemeriksaan integrasi database dilakukan pada checkpoint ini. Uji rollback dan concurrency terhadap PostgreSQL terisolasi masih perlu dilakukan sebelum runner dipakai untuk instalasi baru.
