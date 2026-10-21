# MyMoney

Aplikasi manajemen keuangan berbasis Flutter untuk mahasiswa. MyMoney membantu pengguna mencatat pemasukan dan pengeluaran, mengelola beberapa dompet (Gopay, BCA, Cash), melihat laporan pengeluaran, dan mencatat transaksi hanya dengan mengetik kalimat biasa berkat asisten AI (Google Gemini).

## Anggota Kelompok

| No | Nama | NIM |
|---|---|---|
| 1 | M. Fahrianor | 2409106089 |
| 2 | Miftahul Fauzan | 2409106048 |
| 3 | Muhammad Husein Permadi | 2409106051 |
| 4 | Much. Trigusni Hermawan | 2409106060 |
| 5 | Richo Anan Rizky Putra | 2409106062 |

## Tentang Aplikasi

Mahasiswa sering kesulitan melacak uang saku karena pencatatan manual terasa merepotkan. MyMoney menyederhanakan hal itu: transaksi bisa dicatat lewat formulir atau cukup ditulis dengan bahasa sehari-hari, misalnya `kopi 18rb pakai gopay` atau `gajian 2jt masuk bca`.

### Fitur utama
- Catat transaksi pemasukan dan pengeluaran (tambah, ubah, hapus).
- Tiga dompet: **Gopay**, **BCA**, dan **Cash**. Saldo tiap dompet otomatis berubah mengikuti transaksi.
- **Catat dengan AI**: tulis kalimat bebas (urutan kata boleh acak, boleh singkat seperti `25rb`), AI menentukan judul, nominal, kategori, jenis, dan dompet.
- **AI Chat (Teman Keuangan AI)**: ngobrol soal saldo, minta saran hemat, atau langsung bilang transaksi yang baru terjadi. AI mengingat percakapan dan mengetahui saldo serta pengeluaran pengguna.
- Pencarian transaksi berdasarkan nama, kategori, atau dompet.
- Laporan pengeluaran per kategori.
- Halaman **Profile** dengan tombol **Pengaturan** (mode gelap/terang, tentang aplikasi).
- Tema terang dan gelap (Material 3), tampilan responsif (NavigationBar di HP, NavigationRail di layar lebar).

## Cara Kerja Aplikasi

### Alur pencatatan transaksi
1. Pengguna menekan **Catat Transaksi** di Home.
2. Pengguna mengisi formulir, atau memakai **Isi & Simpan Otomatis** lalu mengetik kalimat bebas.
3. Untuk jalur AI, teks dikirim ke Gemini yang mengembalikan data terstruktur (judul, nominal, kategori, jenis, dompet).
4. Aplikasi mencocokkan dompet lewat `WalletMatcher` (mengenali alias seperti `gopay/gojek`, `bca/rekening/atm`, `cash/tunai`). Jika metode bayar tidak disebut, dipakai Gopay dan pengguna diberi tahu.
5. Transaksi disimpan, lalu saldo dompet yang bersangkutan diperbarui. Mengubah atau menghapus transaksi akan menyesuaikan kembali saldo dompet.

### Alur AI Chat
1. Pesan pengguna dikirim ke Gemini bersama riwayat 10 pesan terakhir dan ringkasan data keuangan (saldo per dompet, pengeluaran per kategori, transaksi terbaru).
2. Gemini menentukan apakah pesan itu **transaksi** atau **obrolan biasa**, lalu membalas dengan bahasa natural.
3. Jika transaksi, aplikasi menyimpannya seperti alur di atas.
4. Jika AI tidak bisa dihubungi (tanpa internet atau key kosong), aplikasi memakai **parser lokal** yang tetap bisa membaca nominal dan dompet dari kalimat bebas.

### Arsitektur
Proyek memakai **Clean Architecture (feature-first)** dengan state management **Cubit (flutter_bloc)**.

```
lib/
├── main.dart
├── firebase_options.dart            # dibuat oleh FlutterFire CLI
├── core/
│   ├── di/                          # dependency injection & ThemeCubit
│   ├── services/                    # GeminiAiService, ApiConfig
│   ├── ui/app_icons.dart            # ikon konsisten
│   └── utils/wallet_matcher.dart    # pencocok dompet
└── features/
    ├── transaction/                 # data / domain / presentation
    ├── wallet/                      # data / domain / presentation
    ├── chat/                        # AI Chat
    ├── report/                      # laporan
    ├── search/                      # pencarian
    └── profile/                     # profil & pengaturan
```

## Cara Menghubungkan dengan Database (Firebase Firestore)

Data transaksi dan dompet disimpan di **Cloud Firestore**.

1. **Buat project Firebase** di [console.firebase.google.com](https://console.firebase.google.com), lalu buka menu **Build > Firestore Database > Create database**.
2. **Pasang tools** (sekali saja):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
3. **Hubungkan project ke aplikasi** dari root proyek:
   ```bash
   flutterfire configure
   ```
   Perintah ini membuat `lib/firebase_options.dart` untuk platform yang dipilih (Android, Web, dan lainnya).
4. **Pastikan dependency terpasang** (sudah ada di `pubspec.yaml`):
   ```bash
   flutter pub add firebase_core cloud_firestore
   ```
5. **Inisialisasi di `main.dart`**:
   ```dart
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```
6. **Terapkan aturan keamanan** dari `firestore.rules`:
   ```bash
   firebase deploy --only firestore:rules
   ```
7. **Jalankan aplikasi.** Data akan muncul di Firestore Console saat transaksi atau dompet pertama dibuat.

Koleksi utama: `wallets` (id, name, balance) dan `transactions` (id, title, amount, date, category, type, walletId, walletName).

## Teknologi
- Flutter & Dart
- flutter_bloc (Cubit), get_it, go_router
- Cloud Firestore (Firebase)
- Google Gemini API (`gemini-2.5-flash`)