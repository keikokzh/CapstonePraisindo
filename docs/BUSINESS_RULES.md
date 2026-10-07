# Business Rules & Assumptions
**Modul**: TRX-01 (Subscription per Produk)
**Status Dokumen**: *Draft / Demo Assumption*

Dokumen ini memisahkan aturan bisnis yang diterapkan dalam prototipe untuk memudahkan penyesuaian oleh analis bisnis atau tim produk. Semua aturan di sini adalah asumsi simulasi awal dan **bukan acuan hukum atau kepatuhan yang tervalidasi (not legally validated)**.

## 1. Bea Meterai (Stamp Duty)
- **Sumber Asumsi**: Demo rules berbasis referensi umum UU No. 10 Tahun 2020. Aturan ini **belum divalidasi** oleh tim Legal/Compliance Praisindo.
- **Logika Prototipe**: 
  - Jika `Gross Amount` (Nilai Transaksi Bruto) > Rp 10.000.000, maka `Stamp Duty` = Rp 10.000.
  - Jika `Gross Amount` <= Rp 10.000.000, maka `Stamp Duty` = Rp 0.
- **Implementasi (Modular)**:
  - Tersimpan secara statis di skrip seed data (`backend/seeds/seed_data.sql`).
  - Untuk generator deterministik frontend, aturan ini terenkapsulasi di `frontend/src/services/api.ts` dalam fungsi `generateDeterministicMockReport`.
  - Apabila ke depan perhitungan akan dilakukan dinamis saat *order entry*, buat service terpisah (misal: `StampDutyCalculator`) agar aturan dapat disesuaikan tanpa menyentuh modul reporting.

## 2. Status Transaksi (Lifecycle)
- `PENDING_NAV`: Menunggu harga NAV hari bursa terbentuk.
- `PENDING_SETTLEMENT`: NAV terbentuk, unit dihitung, namun pembayaran dana dari nasabah/agen ke bank kustodian belum selesai.
- `SETTLED`: Proses tuntas, unit dialokasikan ke nasabah (SID).
- `EXCEPTION`: Terjadi kegagalan rekonsiliasi atau pembayaran.

## 3. Aritmatika Transaksi
- `Fee Amount` = `Gross Amount` × `Persentase Fee` (ditentukan per channel/tier).
- `Net Amount` = `Gross Amount` - `Fee Amount` - `Stamp Duty`.
- `Units` = `Net Amount` / `NAV per Unit`.
- Pembulatan unit adalah **4 angka di belakang koma** sesuai praktik standar reksa dana. Kalkulasi wajib menggunakan presisi aritmatika desimal (*bukan floating point*).
