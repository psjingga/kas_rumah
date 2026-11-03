<p align="center">
  <img src="assets/icon/icon.png" alt="Ikon Kas Rumah" width="120" />
</p>

<h1 align="center">Kas Rumah</h1>

<p align="center">
  Aplikasi pencatat keuangan rumah tangga: pemasukan, pengeluaran, tagihan rutin, anggaran, dan target tabungan.<br/>
  Berjalan <b>offline</b>, dengan semua data tersimpan di HP sendiri.
</p>

<p align="center">
  Flutter 3.44 · Dart 3.12 · Riverpod 3 · Hive CE · fl_chart
</p>

---

## Daftar isi

- [Tentang aplikasi](#tentang-aplikasi)
- [Fitur](#fitur)
  - [Ringkasan bulanan](#1-ringkasan-bulanan)
  - [Riwayat & pencarian](#2-riwayat--pencarian)
  - [Transaksi rutin bulanan](#3-transaksi-rutin-bulanan)
  - [Pengingat & notifikasi](#4-pengingat--notifikasi)
  - [Anggaran per kategori](#5-anggaran-per-kategori)
  - [Target tabungan](#6-target-tabungan)
  - [Kategori buatan sendiri](#7-kategori-buatan-sendiri)
  - [Backup, pulihkan & ekspor CSV](#8-backup-pulihkan--ekspor-csv)
  - [Kunci aplikasi (PIN & sidik jari)](#9-kunci-aplikasi-pin--sidik-jari)
  - [Tema terang / gelap](#10-tema-terang--gelap)
  - [Halaman pembuka & tampilan kosong](#11-halaman-pembuka--tampilan-kosong)
  - [Dompet & transfer](#12-dompet--transfer)
  - [Utang & piutang](#13-utang--piutang)
  - [Catatan & foto struk](#14-catatan--foto-struk)
  - [Laporan](#15-laporan)
- [Alur penggunaan](#alur-penggunaan)
- [Arsitektur](#arsitektur)
- [Struktur folder](#struktur-folder)
- [Model data](#model-data)
- [Teknologi & package](#teknologi--package)
- [Menjalankan proyek](#menjalankan-proyek)
- [Pengujian](#pengujian)
- [Build rilis Android](#build-rilis-android)
- [Privasi & keamanan data](#privasi--keamanan-data)
- [Batasan yang diketahui](#batasan-yang-diketahui)
- [Rencana pengembangan](#rencana-pengembangan)

---

## Tentang aplikasi

**Kas Rumah** dibuat untuk keluarga yang ingin tahu ke mana uangnya pergi setiap bulan, tanpa harus mendaftar akun atau mengirim data ke server.

Masalah yang dijawab:

| Masalah sehari-hari | Solusi di Kas Rumah |
|---|---|
| Lupa mencatat pengeluaran kecil | Form cepat dengan nominal berformat otomatis (`1.500.000`) dan kategori sesuai jenis |
| Tagihan bulanan berulang (listrik, internet, cicilan) | **Transaksi rutin**: cukup sekali diatur, lalu dicatat tiap bulan dengan satu ketukan |
| Lupa bayar tagihan | **Notifikasi pengingat** H-n sebelum jatuh tempo |
| Pengeluaran kebablasan | **Anggaran** per kategori dengan peringatan di 80% dan 100% |
| Ingin menabung untuk tujuan tertentu | **Target tabungan** dengan progres dan saran setoran per bulan |
| Takut data hilang saat ganti HP | **Backup** satu file yang bisa disimpan di Google Drive / WhatsApp |
| Data keuangan bersifat pribadi | **Kunci PIN / sidik jari**, dan semua data hanya ada di HP |

Seluruh antarmuka berbahasa Indonesia, nominal dalam Rupiah (`Rp 1.500.000`), dan tanggal berformat Indonesia (`3 Nov 2026`).

---

## Fitur

Aplikasi memakai navigasi bawah dengan lima tab: **Ringkasan · Riwayat · Anggaran · Tabungan · Lainnya**. Di app bar selalu ada tombol 🔍 **Cari** dan 🔔 **Notifikasi**, dengan angka merah untuk notifikasi yang belum dibaca.

### 1. Ringkasan bulanan

Semua angka dihitung **per bulan**. Bulan dipilih dengan tombol `‹ November 2026 ›`, dan tombol **"Ke bulan ini"** muncul saat sedang melihat bulan lain.

- **Kartu Sisa Saldo:** pemasukan − pengeluaran bulan terpilih.
  - Ada keterangan *"Sisa bulan lalu Rp …"* sebagai informasi.
  - Sisa bulan lalu **tidak dijumlahkan** ke saldo bulan ini.
- **Perbandingan dengan bulan lalu:** misalnya *"▲12% vs bln lalu"* di bawah pemasukan dan pengeluaran.
- **Kartu Anggaran & Tabungan:** status singkat (*"2 hampir habis"*, total tabungan). Ketuk untuk membuka tabnya.
- **Kartu Rutin bulan ini:** daftar transaksi rutin yang belum dicatat. Lihat [Transaksi rutin](#3-transaksi-rutin-bulanan).
- **Geser kiri/kanan** di Ringkasan dan Anggaran untuk pindah bulan.
- **Angka sisa saldo beranimasi** saat berubah.
- **Pie chart Pemasukan vs Pengeluaran:**
  - Bagian tengah menampilkan berapa persen pemasukan yang sudah terpakai.
  - Angkanya berubah merah bila pengeluaran melebihi pemasukan.
  - Irisan bisa diketuk untuk disorot.
- **Pengeluaran per Kategori:** daftar kategori berbar warna dengan persentase, nominal, dan perubahan dari bulan lalu (▲ merah bila naik, ▼ hijau bila turun), urut dari yang terbesar.
- **Tren 6 Bulan:** bar chart pemasukan (hijau) dan pengeluaran (merah) per bulan.
  - Tahan batang untuk melihat nominalnya.
  - Ketuk batang untuk pindah ke bulan itu.

### 2. Riwayat & pencarian

- **Tab Riwayat:** transaksi bulan terpilih **dikelompokkan per hari** (*Hari ini*, *Kemarin*, *Senin, 2 Nov*), masing-masing dengan total bersih harian.
  - Ketuk transaksi untuk mengubah judul, nominal, kategori, atau tanggal.
  - Geser ke kiri untuk menghapus. Snackbar **"Urungkan"** muncul selama 5 detik.
- **Pencarian (🔍):** mencari di **semua bulan**.
  - Kata kunci dicocokkan ke judul, nama kategori, atau nominal. Contoh: `450` menemukan `Rp 450.000`.
  - Filter jenis: Semua / Pemasukan / Pengeluaran.
  - Filter chip kategori. Chip menyesuaikan jenis yang dipilih.
  - Hasil dikelompokkan per bulan dengan total masuk dan keluar.

**Form transaksi**:

| Kolom | Validasi |
|---|---|
| Jenis | Pengeluaran / Pemasukan; kategori ikut berganti |
| Judul / Deskripsi | Wajib, maks. 60 karakter. **Saran dari riwayat**: ketik "ben", lalu pilih "Bensin" dan kategori serta nominal terakhirnya ikut terisi |
| Nominal | Wajib, hanya angka, > 0, otomatis diberi titik ribuan. **Tombol cepat** +10rb, +20rb, +50rb, +100rb, +500rb (dijumlahkan) |
| Kategori | Hanya kategori yang sesuai jenis (bawaan + buatan sendiri) |
| Tanggal | Date picker berbahasa Indonesia |
| *Ulangi tiap bulan* | Opsional: sekaligus membuat transaksi rutin |

### 3. Transaksi rutin (mingguan, bulanan, tahunan) & cicilan

Untuk pemasukan atau pengeluaran berulang, seperti gaji, listrik, internet, SPP, uang jajan mingguan, pajak motor tahunan, atau cicilan.

- **Template rutin** berisi judul, kategori, **nominal default**, dompet, jadwal, dan status aktif/nonaktif.
- **Jadwalnya bisa:**
  - **Mingguan** (*"Tiap Senin"*);
  - **Bulanan** (*"Tiap tgl 5"*; tanggal 29–31 memakai akhir bulan di bulan yang lebih pendek);
  - **Tahunan** (*"Tiap 15 Mar"*).
- **Cicilan / ada batas waktu:** isi jumlah kali bayar (misalnya 12x), dan form langsung menampilkan *"Lunas setelah …"*.
  - Daftar rutin menampilkan progres *"Cicilan 3/12"* lalu *"Lunas ✓"*.
  - Kartu rutin menampilkan *"ke-3/12"*.
  - Setelah lunas, cicilan berhenti muncul dan tidak dihitung di total rutin.
- **Total rutin per bulan** memakai nominal setara bulanan: mingguan ×52/12, tahunan ÷12.
- **Membuatnya:**
  - lewat *Lainnya → Transaksi Rutin*, atau
  - menyalakan **"Ulangi tiap bulan"** saat menambah transaksi.
- **Setiap bulan**, template yang belum dicatat muncul di kartu **"Rutin bulan ini"**:
  - **✓** mencatat dengan nominal default.
  - **Ketuk baris** untuk mengisi nominal khusus bulan itu. Contoh: listrik bulan ini Rp 520.000, padahal default Rp 450.000.
  - Centang **"Jadikan nominal default"** bila nominal baru berlaku untuk bulan berikutnya.
  - **Catat semua** mencatat semuanya sekaligus dengan nominal default.
- **Aturan:**
  - Transaksi rutin **tidak dicatat otomatis**. Ia hanya muncul sebagai pengingat, jadi tidak ada data palsu.
  - Mencatat dua kali di periode yang sama (minggu yang sama untuk rutin mingguan, bulan yang sama untuk bulanan/tahunan) tidak membuat data dobel.
  - Mengubah nominal default tidak mengubah bulan yang sudah tercatat.
  - Menghapus transaksi rutin yang sudah dicatat membuatnya muncul lagi sebagai *belum dicatat*.

### 4. Pengingat & notifikasi

- **Pengingat transaksi rutin:**
  - Isinya misalnya *"Tagihan rutin: Listrik · Jatuh tempo besok (5 Nov 2026) · Rp 450.000"*.
  - Hanya dikirim untuk transaksi rutin aktif yang **belum dicatat**. Begitu dicatat, pengingat bulan itu batal sendiri.
  - Waktunya bisa diatur: Hari H, H-1, H-2, H-3, atau H-7, dengan jam pengingat bebas (default 08.00).
  - Dijadwalkan sampai 3 bulan ke depan dan tetap terkirim walau aplikasi tertutup atau HP di-restart.
- **Peringatan anggaran:** dikirim saat kategori terpakai 80% dan saat terlampaui, masing-masing sekali per bulan.
- **Halaman Notifikasi (🔔):** riwayat notifikasi yang sudah diterima.
  - Ada penanda belum dibaca.
  - Pengingat diberi status **Belum dicatat / Sudah dicatat**. Ketuk untuk langsung membuka form catat.
  - Tersedia *Tandai semua dibaca* dan *Hapus semua*.
- **Ketuk notifikasi di HP** langsung membuka form "Catat …" untuk transaksi rutin tersebut.
- **Halaman Pengingat** juga punya:
  - daftar jadwal terdekat;
  - tombol **Kirim notifikasi uji**;
  - peringatan bila izin notifikasi HP dimatikan, dengan tombol *Buka pengaturan*.

> Notifikasi memakai jadwal *inexact*: Android boleh menggesernya beberapa menit demi hemat baterai, sehingga aplikasi tidak perlu izin "alarm tepat waktu".

### 5. Anggaran per kategori

- Tetapkan **batas pengeluaran per bulan** untuk kategori mana pun, misalnya Makanan Rp 3.000.000.
- **Tab Anggaran** menampilkan:
  - total anggaran bulan ini (terpakai / batas, sisa atau lebih);
  - setiap kategori dengan bar berwarna: 🟢 < 80%, 🟠 80–99%, 🔴 ≥ 100%;
  - teks *"Rp 2.550.000 dari Rp 3.000.000 · sisa Rp 450.000"*.
- Ketuk kategori untuk mengubah atau menghapus batasnya.
- Batas berlaku sama setiap bulan. Pemakaian dihitung dari transaksi bulan yang dipilih.

### 6. Target tabungan

- Buat target seperti *"Dana darurat Rp 10.000.000"*, dengan **tenggat** (opsional), ikon, dan warna.
- Kartu target menampilkan progres (%), *"Rp x dari Rp y"*, dan bila ada tenggat, **setoran yang dibutuhkan per bulan** agar target tercapai tepat waktu.
- **Setor / Tarik** dengan opsi **"Catat juga sebagai transaksi"**:
  - setor menjadi pengeluaran kategori **Tabungan**;
  - tarik menjadi pemasukan kategori **Ambil Tabungan**;
  - akibatnya sisa saldo bulanan ikut mencerminkan uang yang dipindahkan.
- Riwayat setoran bisa dibatalkan dengan menggeser. Transaksi terkaitnya ikut terhapus.

### 7. Kategori buatan sendiri

- Ada 14 **kategori bawaan**:
  - **Pemasukan:** Gaji, Bonus, Hasil Usaha, Ambil Tabungan, Pemasukan Lain.
  - **Pengeluaran:** Makanan, Belanja Rumah Tangga, Tagihan, Transportasi, Pendidikan, Kesehatan, Hiburan, Tabungan, Pengeluaran Lain.
- Tambah kategori sendiri (misalnya *Arisan*, *Uang sekolah anak*, *Kiriman orang tua*) dengan nama, jenis, **31 pilihan ikon**, dan **12 pilihan warna**.
- Nama kembar dalam jenis yang sama ditolak.
- **Ganti nama atau warna:** semua transaksi lama ikut tampil dengan nama atau warna baru.
- **Hapus kategori:** transaksinya tetap ada dan tampil sebagai *"Kategori dihapus"*. Sebelum menghapus, aplikasi memberi tahu berapa transaksi yang memakainya.

### 8. Backup, pulihkan & ekspor CSV

Menu ini ada di *Lainnya → Backup & Ekspor*.

- **Kunci dengan kata sandi (disarankan):** saat membuat backup, isi kata sandi (min. 6 karakter, diketik dua kali).
  - File dienkripsi **AES-256-GCM** dengan kunci dari **PBKDF2-HMAC-SHA256** (150.000 iterasi, salt acak).
  - Saat memulihkan, aplikasi meminta kata sandi. Kata sandi salah atau file yang diubah ditolak.
  - **Kata sandi tidak bisa dipulihkan bila lupa.**
- **Buat backup & bagikan:** satu file `kas-rumah-backup-YYYY-MM-DD.json` berisi **semua data**:
  - transaksi dan transaksi rutin;
  - dompet dan transfer;
  - utang dan piutang;
  - catatan transaksi (foto struk tidak ikut);
  - kategori sendiri, anggaran, dan target tabungan;
  - pengaturan pengingat.

  File dibagikan lewat share sheet Android, misalnya ke Google Drive, WhatsApp, atau email.
- **Pulihkan dari file backup:**
  - Aplikasi menampilkan ringkasan isi backup sebelum mengganti data.
  - File yang rusak atau bukan backup Kas Rumah ditolak, dan data tidak berubah sedikit pun.
- **Ekspor CSV untuk Excel:** per bulan atau semua transaksi.
  - Kolom: `Tanggal;Jenis;Kategori;Judul;Nominal`.
  - Pemisahnya `;` supaya langsung rapi di Excel berbahasa Indonesia.
- **Penanda backup:** tanggal backup terakhir terlihat di tab Lainnya, dan **berwarna merah** bila belum backup lebih dari 30 hari.

### 9. Kunci aplikasi (PIN & sidik jari)

- **PIN 4–6 angka**, dibuat dengan mengetik dua kali.
  - PIN **tidak disimpan apa adanya**. Yang disimpan hanya hash SHA-256 dengan salt acak.
- **Buka dengan sidik jari / wajah:** opsional, bila HP mendukung.
- **Kapan terkunci:** saat aplikasi dibuka, dan lagi setelah **30 detik di latar belakang**.
- **Ubah atau matikan PIN:** wajib memasukkan PIN lama.
- **Lupa PIN:** hapus data aplikasi lewat Pengaturan HP, lalu pulihkan dari file backup.

### 10. Tema terang / gelap

- Pilih **Sistem / Terang / Gelap** di tab Lainnya.
- Warna utama aplikasi adalah hijau-teal (`#00796B`).
- Font memakai **Plus Jakarta Sans** (OFL), disertakan di aplikasi sehingga tampil walau offline.
- Warna pemasukan, pengeluaran, dan peringatan menyesuaikan mode gelap agar tetap kontras.

### 11. Halaman pembuka & tampilan kosong

- **Halaman pembuka (sekali saja untuk pengguna baru)**, 4 langkah dan semuanya boleh dilewati:
  1. Perkenalan aplikasi.
  2. Pemasukan rutin (gaji).
  3. Tagihan bulanan, dipilih dari daftar cepat: Listrik, Air PDAM, Internet, Pulsa, Cicilan, SPP, Arisan.
  4. Pasang PIN.
- **Pengguna lama** yang sudah punya data tidak melihat halaman pembuka.
- **Tampilan kosong** di Riwayat, Anggaran, Tabungan, dan Transaksi Rutin memakai ikon, penjelasan singkat, dan tombol aksi langsung.
- **Getar halus (haptic)** saat menyimpan, mencatat, dan menghapus.

---

### 12. Dompet & transfer

Dompet dicatat **manual**, tidak tersambung ke bank atau e-wallet.

- **Dompet** berisi nama, jenis (Tunai / Bank / E-wallet / Lainnya), saldo awal, dan warna. Contoh: Tunai, BCA, BRI, GoPay, DANA.
  - Transaksi lama otomatis masuk ke **Dompet Utama**, yang namanya bisa diganti.
  - Dompet pertama menjadi **dompet bawaan** untuk transaksi baru. Dompet lain bisa dijadikan bawaan lewat menu di detail dompet.
- **Pilih dompet** di form transaksi ("Dibayar dari dompet" / "Masuk ke dompet"), transaksi rutin, dan setor/tarik tabungan.
- **Saldo tiap dompet** = saldo awal + pemasukan − pengeluaran ± transfer.
  - Kartu **"Uang saat ini"** di Ringkasan menampilkan total dan saldo per dompet.
- **Transfer antar-dompet**, misalnya tarik tunai BCA → Tunai atau top up GoPay. Transfer:
  - **tidak dihitung** sebagai pemasukan atau pengeluaran, jadi grafik dan anggaran tetap benar;
  - tetap tampil di Riwayat pada harinya.
- **Sesuaikan saldo:** isi saldo sebenarnya (misalnya dari m-banking), lalu selisihnya dicatat sebagai penyesuaian.
- **Hapus atau arsipkan dompet:**
  - dompet yang belum pernah dipakai bisa dihapus;
  - dompet yang sudah punya riwayat hanya bisa **diarsipkan**, supaya riwayatnya tetap utuh.
- **Pencarian** bisa difilter per dompet. Nama dompet tampil di tiap transaksi bila dompet aktif lebih dari satu.

### 13. Utang & piutang

Dibuka lewat *Lainnya → Utang & Piutang*, atau kartu di Ringkasan bila ada yang belum lunas.

- **Jenis catatan:**
  - **Saya pinjam** (utang): misalnya *"Pinjam dari Bu RT Rp 500.000"*.
  - **Saya pinjamkan** (piutang): misalnya *"Dipinjam oleh Pak Budi Rp 1.000.000"*.
- Isinya tanggal pinjam, **jatuh tempo** (opsional), dan catatan.
- **Catat ke dompet:**
  - Uang pinjaman masuk ke dompet, atau uang yang dipinjamkan keluar dari dompet.
  - Pembayaran mengubah saldo dompet ke arah sebaliknya.
  - Perpindahan ini **tidak dihitung** sebagai pemasukan atau pengeluaran.
- **Pembayaran sebagian:**
  - Progres tampil sebagai *"Dibayar Rp x dari Rp y"*.
  - Nominal otomatis terisi sisa utang, jadi untuk melunasi cukup ketuk Simpan.
  - Saat lunas, aplikasi menampilkan *"Lunas! 🎉"*.
- **Ringkasan** di halaman ini: total *Utang saya* dan *Piutang*, filter Belum lunas / Lunas, dan status *"Lewat 3 hari"* berwarna merah.
- **Pengingat jatuh tempo** mengikuti pengaturan H-n dan jam pengingat.
  - Ketuk notifikasinya untuk langsung membuka detail utang/piutang.
  - Di halaman Notifikasi, statusnya tampil sebagai *Lunas / Belum lunas*.
- **Menghapus** catatan atau pembayaran ikut membatalkan perpindahan uang di dompet.

### 14. Catatan & foto struk

- Setiap transaksi bisa diberi **catatan** (maks. 200 karakter) dan **foto struk** dari kamera atau galeri.
  - Foto dikecilkan otomatis dan disimpan di folder aplikasi, jadi tetap ada walau foto aslinya di galeri dihapus.
  - Ketuk foto untuk melihat layar penuh (bisa di-zoom).
- **Riwayat** menampilkan ikon kecil bila transaksi punya catatan atau foto.
- **Pencarian** juga mencocokkan isi catatan, dan **CSV** punya kolom *Catatan*.
- Foto yang tidak lagi dipakai (transaksi dihapus, atau form dibatalkan setelah memotret) dibersihkan otomatis saat aplikasi dibuka.
- **Foto struk tidak ikut file backup**, karena file backup berupa teks. Catatan tetap ikut.

### 15. Laporan

Dibuka lewat *Lainnya → Laporan*, atau tombol **Laporan** di kartu Tren pada Ringkasan.

- **Tahunan:** pilih tahun, lalu lihat:
  - total pemasukan, pengeluaran, dan sisa setahun;
  - **rasio menabung** (persen pemasukan yang tersisa);
  - **rata-rata pengeluaran per bulan**, dihitung dari bulan yang ada datanya;
  - **bulan paling boros**;
  - grafik 12 bulan, tabel per bulan, dan pengeluaran per kategori setahun.

  Ketuk bulan di tabel atau grafik untuk membukanya di Ringkasan.
- **Bandingkan:** pilih dua bulan (awalnya bulan lalu vs bulan ini).
  - Tampil pemasukan, pengeluaran, dan sisa, beserta pengeluaran per kategori.
  - Perubahan ditandai ▲/▼: merah bila lebih buruk, hijau bila lebih baik, dan *"baru"* bila bulan pertama belum ada.
- **Bulanan:** kartu laporan berisi ringkasan, kategori, dan 5 pengeluaran terbesar. Bisa dibagikan sebagai:
  - **Gambar (PNG)**, cocok untuk WhatsApp;
  - **PDF A4**, berisi ringkasan, bar kategori, dan tabel **semua transaksi** (tanggal, judul + catatan, kategori, dompet, nominal) dengan nomor halaman. Siap dicetak.

## Alur penggunaan

```
Pertama kali
 ├─ Lainnya → Transaksi Rutin → tambah Gaji (tgl 25), Listrik (tgl 5), Internet (tgl 10) …
 ├─ Anggaran → + Anggaran → Makanan Rp 3.000.000, Transportasi Rp 800.000 …
 ├─ Tabungan → + Target → Dana darurat Rp 10.000.000 (tenggat Des 2027)
 └─ Lainnya → Kunci Aplikasi (opsional) & Backup

Sehari-hari
 ├─ Tombol + Transaksi → isi judul, nominal, kategori
 └─ Notifikasi "Tagihan rutin: Listrik · besok" → ketuk → Simpan

Akhir bulan
 ├─ Ringkasan → lihat sisa saldo, pie chart, rincian kategori, tren
 ├─ Tabungan → Setor sisa uang ke target
 └─ Lainnya → Backup & Ekspor → Buat backup
```

---

## Arsitektur

Struktur **feature-first + clean architecture** ringan. Setiap fitur punya tiga lapisan:

```
domain/        Entitas & logika murni (tanpa Flutter UI / Hive) → mudah diuji
data/          Implementasi penyimpanan (Hive) & layanan platform (notifikasi, biometrik)
presentation/  Provider Riverpod (state & aksi) + halaman/widget
```

**Alur data:**

```
UI (ConsumerWidget)
   │ ref.watch / ref.read(...notifier)
   ▼
Notifier Riverpod (TransactionsNotifier, BudgetLimitsNotifier, …)
   │ hanya mengenal interface repository (domain)
   ▼
Repository (HiveTransactionRepository, HiveBudgetRepository, …)
   ▼
Hive (box: transactions, recurring, settings)
```

**Prinsip penting:**

- **Provider turunan:** `financeSummaryProvider`, `budgetStatusProvider`, `pendingRecurringProvider`, `plannedRemindersProvider`, dan sejenisnya dihitung ulang otomatis saat data berubah. Tidak ada sinkronisasi manual.
- **Dependency injection:** semua repository dan layanan platform adalah provider yang di-*override* di `main.dart` dengan implementasi Hive dan plugin asli, dan di tes dengan versi di memori.
- **Fungsi murni untuk logika penting**, supaya teruji tanpa UI:
  - `FinanceSummary.from`
  - `planReminders`
  - `budgetStatuses` / `pendingBudgetAlerts`
  - `TransactionFilter`
  - `BackupService`
- **Efek samping terpusat di `main.dart`.** `ProviderContainer.listen` dipakai untuk:
  - menjadwalkan ulang notifikasi setiap kali `plannedRemindersProvider` berubah;
  - mengirim peringatan anggaran setiap kali `currentBudgetStatusProvider` berubah.
- **Kategori disimpan sebagai ID:** transaksi di Hive hanya menyimpan ID kategori. Label, ikon, dan warna terbaru diambil dari daftar kategori saat dimuat.
- **Adapter Hive ditulis manual** (tanpa build_runner):
  - Enum disimpan sebagai *nama*.
  - Kolom baru ditambahkan di akhir dan dibaca hanya bila byte-nya ada, sehingga data versi lama tetap terbaca.

---

## Struktur folder

```
lib/
├── main.dart                       # init Hive, locale, notifikasi; override provider; listener efek samping
├── app/
│   ├── app.dart                    # MaterialApp, tema terang/gelap, lokal id_ID, AppLockGate
│   └── home_shell.dart             # navigasi bawah 5 tab, app bar, FAB per tab
├── core/
│   ├── database/hive_database.dart # registrasi adapter & buka box
│   ├── navigation/home_tab.dart    # tab aktif (agar kartu bisa pindah tab)
│   ├── theme/money_colors.dart     # warna pemasukan/pengeluaran sesuai mode terang/gelap
│   ├── widgets/                    # EmptyState, InsightCard
│   └── utils/
│       ├── formatters.dart         # Rupiah, tanggal, input ribuan
│       └── month.dart              # ekstensi bulan (firstOfMonth, addMonths, …)
└── features/
    ├── transactions/               # transaksi, kategori, transaksi rutin, ringkasan, riwayat, pencarian
    │   ├── domain/   entities/ (transaction, transaction_category, recurring_transaction,
    │   │                        finance_summary, transaction_filter)  repositories/
    │   ├── data/     adapters/ (TypeAdapter Hive)  repositories/ (Hive)
    │   └── presentation/ providers/  pages/ (summary_tab, history_tab, form, search,
    │                                        recurring, categories)  widgets/
    ├── reminders/                  # perencana pengingat, layanan notifikasi, riwayat notifikasi
    ├── budgets/                    # anggaran & peringatan
    ├── goals/                      # target tabungan
    ├── wallets/                    # dompet, transfer, penyesuaian saldo
    ├── debts/                      # utang & piutang
    ├── reports/                    # laporan tahunan, bandingkan bulan, PDF/gambar
    ├── backup/                     # backup JSON (opsional terenkripsi), pulihkan, ekspor CSV
    └── settings/                   # tema, kunci PIN/biometrik, tab Lainnya

test/                               # unit & widget test (repository di memori, jam tetap)
assets/icon/                        # sumber ikon aplikasi
assets/fonts/                       # Plus Jakarta Sans + lisensi OFL
```

---

## Model data

| Entitas | Kolom utama |
|---|---|
| `Transaction` | `id`, `title`, `amount` (double, > 0), `type` (income/expense), `category`, `date`, `recurringId?`, `walletId?`, `note`, `photoPath?` |
| `TransactionCategory` | `id`, `label`, `type`, `iconKey`, `color`, `builtIn` |
| `RecurringTransaction` | `id`, `title`, `amount` (default), `type`, `category`, `frequency` (weekly/monthly/yearly), `dayOfMonth`, `weekday`, `monthOfYear`, `totalOccurrences?` (cicilan), `startMonth`, `active`, `walletId?` |
| `SavingsGoal` | `id`, `name`, `target`, `deadline?`, `iconKey`, `colorValue`, `deposits[]` |
| `GoalDeposit` | `id`, `amount` (+ setor / − tarik), `date`, `transactionId?` |
| Anggaran | `Map<categoryId, limit>` |
| `ReminderSettings` | `enabled`, `daysBefore`, `hour`, `minute`, `budgetAlerts` |
| `SecuritySettings` | `pinHash`, `salt`, `pinLength`, `biometric` |
| `NotificationEntry` | `id`, `title`, `body`, `time`, `recurringId?`, `dueDate?`, `read` |
| `Wallet` | `id`, `name`, `type` (cash/bank/ewallet/other), `colorValue`, `initialBalance`, `archived` |
| `Transfer` | `id`, `fromWalletId?`, `toWalletId?` (salah satu kosong = penyesuaian / utang-piutang), `amount`, `date`, `note`, `debtId?` |
| `Debt` | `id`, `person`, `direction` (iOwe/theyOwe), `amount`, `date`, `dueDate?`, `note`, `walletId?`, `transferId?`, `payments[]` |
| `DebtPayment` | `id`, `amount`, `date`, `transferId?` |

**Penyimpanan Hive:**

| Box | Isi |
|---|---|
| `transactions` | `Transaction` (TypeAdapter id 0) |
| `recurring` | `RecurringTransaction` (TypeAdapter id 1) |
| `transfers` | Transfer & penyesuaian saldo (map, key = ID) |
| `settings` | Map biasa: dompet, kategori sendiri, anggaran, target tabungan, pengaturan pengingat, riwayat & jadwal notifikasi, tema, keamanan, waktu backup terakhir |

---

## Teknologi & package

| Kebutuhan | Package |
|---|---|
| State management | `flutter_riverpod` 3 (Notifier, tanpa code generation) |
| Database lokal | `hive_ce`, `hive_ce_flutter` |
| Grafik | `fl_chart` |
| Format angka & tanggal | `intl`, `flutter_localizations` |
| ID unik | `uuid` |
| Notifikasi terjadwal | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Backup & ekspor | `share_plus`, `file_picker`, `path_provider` |
| Foto struk | `image_picker` |
| Kunci aplikasi | `crypto` (SHA-256), `local_auth` (biometrik) |
| Backup terenkripsi | `cryptography` (PBKDF2 + AES-GCM) |
| Laporan PDF | `pdf` |
| Ikon aplikasi | `flutter_launcher_icons` (dev) |

---

## Menjalankan proyek

Prasyarat: [FVM](https://fvm.app) dengan Flutter **3.44.9** (lihat `.fvmrc`), Android SDK, dan HP/emulator Android 7.0+.

```bash
fvm install            # memasang Flutter sesuai .fvmrc
fvm flutter pub get
fvm flutter run        # pilih perangkat
```

Membuat ulang ikon setelah mengganti `assets/icon/*.png`:

```bash
fvm dart run flutter_launcher_icons
```

**Konfigurasi Android yang sudah disiapkan:**

- *Core library desugaring* untuk notifikasi terjadwal.
- Izin `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, dan `USE_BIOMETRIC`.
- Receiver notifikasi terjadwal dan boot.
- `MainActivity` turunan `FlutterFragmentActivity`, karena dibutuhkan `local_auth`.

---

## Pengujian

```bash
fvm flutter analyze
fvm flutter test
```

Ada **101 tes**, mencakup:

- **Unit:**
  - ringkasan, saldo, dan tren;
  - filter pencarian;
  - transaksi rutin (jatuh tempo, belum/sudah dicatat, tanpa dobel);
  - perencana pengingat;
  - riwayat notifikasi (termasuk saat izin mati);
  - anggaran dan peringatan;
  - target tabungan;
  - backup bolak-balik dan CSV;
  - PIN dan kunci otomatis;
  - adapter Hive, termasuk kompatibilitas data lama.
- **Widget:**
  - form dan validasi;
  - geser hapus dan urungkan;
  - navigasi tab;
  - transaksi rutin;
  - pencarian;
  - halaman pengingat dan notifikasi;
  - anggaran, tabungan, dan kategori;
  - layar PIN;
  - tema gelap;
  - riwayat per hari, saran judul, dan tombol nominal cepat;
  - perbandingan bulan lalu, kartu Anggaran & Tabungan, dan geser bulan;
  - halaman pembuka;
  - dompet: saldo, transfer, penyesuaian, arsip, filter, adapter, backup v2/v1, dan alur UI;
  - rutin mingguan, tahunan, dan cicilan, beserta pengingatnya;
  - utang-piutang (efek ke dompet, pelunasan, pengingat, backup);
  - catatan, foto struk, dan pembersihan foto yatim;
  - laporan tahunan, perbandingan bulan, PDF, backup terenkripsi (kata sandi salah / file diubah), dan UI laporan.

Tes memakai repository di memori dan **jam tetap** (`3 Nov 2026 09.00`), sehingga hasilnya sama kapan pun dijalankan.

---

## Build rilis Android

1. Buat keystore **sekali** saja. Simpan baik-baik dan jangan di-commit:
   ```bash
   keytool -genkey -v -keystore ~/kas-rumah.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kasrumah
   ```
2. Buat `android/key.properties`. File ini sudah tercantum di `.gitignore`:
   ```properties
   storeFile=/Users/<nama>/kas-rumah.jks
   storePassword=...
   keyAlias=kasrumah
   keyPassword=...
   ```
3. Build:
   ```bash
   fvm flutter build appbundle   # untuk Google Play
   fvm flutter build apk         # untuk dibagikan langsung
   ```

Tanpa `key.properties`, build release memakai kunci debug. Ini hanya cocok untuk uji coba, bukan untuk Play Store.

---

## Privasi & keamanan data

- **Tanpa akun dan tanpa server.** Semua data tersimpan lokal di HP (Hive).
- **Tidak ada fitur online**: tanpa analytics, iklan, atau pelacakan; data tidak dikirim ke mana pun.
- **PIN** hanya disimpan sebagai hash SHA-256 + salt acak.
- **File backup bisa dikunci kata sandi** (AES-256-GCM). Backup tanpa kata sandi berupa teks biasa, jadi simpan di tempat yang aman.
- **Layar kunci** menutupi seluruh aplikasi, termasuk dialog, dan menyembunyikan isinya dari pembaca layar saat terkunci.

---

## Batasan yang diketahui

- Data hanya ada di satu HP. Belum ada sinkronisasi antar-anggota keluarga.
- Backup tanpa kata sandi tetap tersedia, dan berupa teks biasa (JSON).
- Riwayat Notifikasi disusun dari jadwal. Bila izin notifikasi mati, pengingat tidak dicatat. Namun notifikasi yang ditutup tanpa dibuka tetap tercatat sebagai "terkirim".
- Pengingat bisa terlambat beberapa menit karena memakai jadwal *inexact*.
- Nominal dalam Rupiah bulat (tanpa desimal) dan hanya mata uang Rupiah.

---

## Rencana pengembangan

- [ ] Backup otomatis terjadwal ke Google Drive
- [ ] Widget layar utama (sisa saldo & tombol tambah cepat)
- [ ] Sinkronisasi antar-anggota keluarga
- [ ] Baca struk otomatis (OCR offline dengan ML Kit)

---

<p align="center">Dibuat dengan Flutter 💚 untuk keuangan keluarga yang lebih tertata.</p>
