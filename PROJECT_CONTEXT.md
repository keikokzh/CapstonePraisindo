# Konteks project CapstonePraisindo

Tim: Raiyan, Keiko, Jhonata. Modul reporting IMS 2026 URS dikembangkan terpisah untuk integrasi ke aplikasi utama.

- Stack: React/TypeScript/Vite; Go/Gin/GORM; PostgreSQL (Neon untuk database bersama).
- Baseline: SQL V2 Pak Hazy. Sumber eksekusi resmi ada di backend/internal/migration/sql; sumber referensi lokal tetap read-only.
- TRX-01 Subscription per Produk adalah laporan pertama. Laporan berikutnya: Redemption, Switching, Monthly Account Statement.
- Pertahankan desain HTML/PDF Pak Hazy dan dokumentasikan perubahan spesifikasi bersama kode.
- Baca README.md, docs/PROGRESS.md, docs/DATABASE_V2.md dan docs/SCHEMA_V2_MAPPING.md. Klaim dalam dokumen harus dibedakan dari bukti pengujian aktual.
- Jangan membuat data fallback frontend. Sample tersimpan pada database tetap harus disebut sample.
- CLOSED adalah status terpisah, tidak otomatis SETTLED. Business Date header belum memiliki sumber operasional yang dikonfirmasi.
- Jangan menjalankan migration/seed terhadap database bersama tanpa tugas yang jelas. Jangan mengubah SQL baseline yang sudah diterapkan.
- Jangan menampilkan/commit kredensial. .env dan variasinya diabaikan Git; .env.example hanya placeholder.
- Verifikasi query, join cardinality, perhitungan, filter dan ekspor dengan bukti, bukan sekadar HTTP 200. LEFT JOIN sendiri tidak mencegah duplikasi.
- Aturan bea meterai prototipe belum tervalidasi; jangan menyatakannya sebagai kebijakan hukum final.
