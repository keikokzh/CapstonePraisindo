# Pemetaan TRX-01 ke PostgreSQL V2

Sumber baseline: paket SQL V2 Pak Hazy. Pemetaan di bawah menggambarkan kode aktual; relasi yang belum dikonfirmasi ditandai sebagai gap.

| Field | Sumber aktual | Catatan |
|---|---|---|
| order_id / fund_id | UUID order_txn / product | String di API dan frontend |
| transaction_code | TX- + 8 karakter terakhir order_id | Alias tampilan, tidak dijamin unik; identitas tetap UUID lengkap. Sort masih memakai 8 karakter pertama dan pencarian belum memakai alias ini: gap terbuka. |
| business_date | order_txn.business_date | Tanggal transaksi/filter, belum menjadi sumber Business Date header |
| customer_name | customer via cif | Join wajib |
| product_name | product via product_id | Join wajib |
| sid | investor_account via cif + product_id + status ACTIVE | Keunikan dan relevansi historis akun perlu divalidasi; bukan bukti otomatis relasi satu-ke-satu |
| channel_type | order.agent_id → selling_agent → distribution_network | Kardinalitas masih perlu dibuktikan; fallback Direct saat join kosong belum terkonfirmasi |
| nav_per_unit | product_nav pada product_id dan business_date yang sama | Bukan NAV terbaru. NAV yang hilang masih menjadi 0: perlu penanganan data tidak tersedia, tidak diasumsikan NAV transaksi nol |
| settlement_date | settlement_instruction via order_id | Banyak instruksi per order dapat menggandakan baris; aturan pemilihan perlu divalidasi |
| gross/fee/stamp/net/units | Kolom order_txn | Nilai tersimpan, bukan generator browser |
| lifecycle_status | Enum V2 | SETTLED; PENDING_FUND/NAV/SETTLEMENT; EXCEPTION; CLOSED |

## Counter dan filter

Tab Closed ditambahkan tanpa mengubah status data. All memasukkan semua status.
Counter chips mengabaikan filter dropdown status dan tab aktif; filter lain dipertahankan. Baris dan KPI mengikuti kedua filter status tersebut. Perilaku ini harus dijelaskan bila user memilih dropdown sekaligus tab.
Sample resmi berisi 10 subscription: 6 SETTLED, 2 PENDING_FUND, 1 PENDING_SETTLEMENT, 1 CLOSED. Ini pemeriksaan sample file, bukan verifikasi ulang Neon.

## Business Date

Sumber tanggal operasional global belum disepakati. Header menampilkan belum tersedia dan jam contoh 21:40 dihapus. Tanggal komputer, MAX(business_date), dan akhir filter tidak boleh diasumsikan sebagai tanggal operasional.

## Migration

Lihat DATABASE_V2.md. Runner resmi mengakses SQL tertanam, bukan folder referensi yang tidak ikut Git. Runner lama dan seed V1 dinonaktifkan. Tidak ada migration atau seed yang dijalankan pada checkpoint ini.
