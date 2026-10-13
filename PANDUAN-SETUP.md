# Panduan setup Stripmap Irigasi di infraproject.online

Website ini terdiri dari tiga bagian:

| Bagian | Fungsi |
|---|---|
| `index.html` (di cPanel) | Halaman website yang dibuka pengunjung |
| Supabase | Database stripmap + login Google + daftar editor |
| Google Cloud | Menyediakan tombol "Masuk dengan Google" |

**Cara kerja akses:**
- **Viewer:** siapa pun yang membuka infraproject.online bisa melihat stripmap dan export PDF tanpa login.
- **Editor:** orang yang emailnya ada di daftar editor. Setelah *Masuk dengan Google*, tombol tambah/edit/hapus muncul.
- **Admin:** paluinpresiii@gmail.com. Admin bisa menambah atau menghapus editor lewat tombol **Kelola editor**.
- Calon editor menekan **Minta akses editor**, yang membuka email ke admin. Admin lalu menambahkan alamat Gmail orang tersebut.

Waktu setup sekitar 20–30 menit. Lakukan langkahnya berurutan.

---

## 1. Buat project Supabase

1. Buka https://supabase.com, lalu daftar atau masuk (bisa pakai akun GitHub atau Google).
2. Klik **New project**.
   - **Name:** `stripmap-irigasi`
   - **Database password:** buat password yang kuat dan simpan baik-baik.
   - **Region:** `Southeast Asia (Singapore)`, yang paling dekat ke Indonesia.
3. Tunggu 1–2 menit sampai project siap.

## 2. Jalankan skrip database

1. Di Supabase, buka menu **SQL Editor**, lalu **New query**.
2. Buka file `supabase-setup.sql`, salin **seluruh isinya**, tempel ke editor, lalu klik **Run**.
3. Pastikan muncul pesan *Success. No rows returned*.

Skrip ini membuat tabel, mengatur hak akses (semua boleh melihat, hanya editor yang boleh mengubah), menjadikan paluinpresiii@gmail.com sebagai admin, dan memasukkan data stripmap yang sudah ada.

## 3. Siapkan login Google

### 3a. Ambil alamat callback dari Supabase
1. Supabase: **Authentication › Sign In / Providers › Google**.
2. Salin **Callback URL (for OAuth)**. Bentuknya `https://xxxxxxxx.supabase.co/auth/v1/callback`. Biarkan halaman ini terbuka.

### 3b. Buat OAuth Client di Google Cloud
1. Buka https://console.cloud.google.com dan masuk dengan Gmail Anda.
2. Buat project baru, misalnya `Stripmap Irigasi`.
3. Buka **APIs & Services › OAuth consent screen** (atau **Google Auth Platform › Branding**).
   - **User type:** External
   - **App name:** Stripmap Irigasi
   - **User support email** dan **Developer contact:** paluinpresiii@gmail.com
   - **Authorized domains:** tambahkan `infraproject.online` dan `supabase.co`
   - Simpan. Lalu di bagian **Audience / Publishing status**, klik **Publish app** supaya semua akun Gmail bisa login, bukan hanya akun tester.
4. Buka **APIs & Services › Credentials › Create credentials › OAuth client ID**.
   - **Application type:** Web application
   - **Authorized JavaScript origins:** `https://infraproject.online` (tambahkan juga `https://www.infraproject.online` jika situs bisa dibuka dengan www)
   - **Authorized redirect URIs:** tempel Callback URL dari langkah 3a
   - Klik **Create**, lalu salin **Client ID** dan **Client secret**.

### 3c. Aktifkan Google di Supabase
1. Kembali ke halaman Google provider di Supabase, nyalakan **Enable Sign in with Google**.
2. Tempel **Client ID** dan **Client Secret**, lalu **Save**.
3. Buka provider **Email** dan **matikan** (disable). Website ini hanya memakai login Google, jadi tidak ada yang bisa mendaftar dengan email lain.

### 3d. Daftarkan alamat website
1. Supabase: **Authentication › URL Configuration**.
2. **Site URL:** `https://infraproject.online`
3. **Redirect URLs:** tambahkan
   - `https://infraproject.online/**`
   - `https://www.infraproject.online/**`
4. Simpan.

## 4. Isi kunci Supabase di `index.html`

1. Supabase: **Project Settings › API** (atau **Data API / API Keys**). Salin:
   - **Project URL**, contoh `https://abcd1234.supabase.co`
   - **anon public** key (atau **publishable** key)
2. Buka `index.html` dengan Notepad atau VS Code, lalu cari bagian `CONFIG` di dekat bagian bawah file:

   ```js
   const CONFIG = {
     SUPABASE_URL: "https://ISI-PROJECT-REF.supabase.co",
     SUPABASE_ANON_KEY: "ISI-ANON-KEY",
     ADMIN_EMAIL: "paluinpresiii@gmail.com",
   };
   ```
3. Ganti kedua nilai `ISI-...` dengan nilai dari Supabase, lalu simpan.

> Anon key memang dirancang untuk diletakkan di website publik. Keamanan data dijaga oleh aturan akses (RLS) yang dibuat skrip SQL. **Jangan** pernah memakai `service_role` key di file ini.

## 5. Upload ke cPanel

1. Masuk ke cPanel hosting Anda, lalu buka **File Manager › public_html**.
2. Jika sudah ada `index.html` lama, ganti namanya dulu menjadi `index-lama.html` sebagai cadangan.
3. **Upload** `index.html` yang baru.
4. Pastikan situs memakai HTTPS. Di cPanel buka **SSL/TLS Status**, lalu jalankan **Run AutoSSL** bila perlu. Login Google tidak berjalan di `http://`.

## 6. Uji coba

1. Buka https://infraproject.online di jendela biasa. Data stripmap harus tampil dengan label **Mode viewer**, tanpa tombol edit.
2. Klik **Masuk editor**, lalu pilih akun paluinpresiii@gmail.com. Setelah kembali ke website, label berubah menjadi **Mode admin** dan tombol edit muncul.
3. Klik **Kelola editor** untuk menambah editor.
4. Buka website di jendela incognito, lalu klik **Minta akses editor**. Aplikasi email harus terbuka dengan pesan yang sudah terisi.

## Menambah editor baru (rutin)

1. Calon editor menekan **Minta akses editor** dan mengirim email berisi alamat Gmail-nya.
2. Anda masuk ke website, klik **Kelola editor**, ketik alamat Gmail tersebut, pilih **Editor**, lalu **Tambah**.
3. Beri tahu orang tersebut untuk klik **Masuk editor** memakai Gmail itu.

Untuk mencabut akses, klik ikon hapus di sebelah emailnya di **Kelola editor**.

## Jika ada masalah

| Gejala | Penyebab umum |
|---|---|
| Muncul banner "Mode pratinjau: Supabase belum dikonfigurasi" | `CONFIG` di index.html belum diisi atau salah ketik |
| "Data tidak bisa dimuat dari server" | Project URL / anon key salah, atau skrip SQL belum dijalankan |
| Login Google error `redirect_uri_mismatch` | Callback URL di Google Cloud tidak sama persis dengan yang di Supabase |
| Setelah login kembali ke `localhost` atau halaman salah | Site URL / Redirect URLs di Supabase belum diisi (langkah 3d) |
| Sudah login tapi tetap "Mode viewer" | Email belum ada di daftar editor, atau berbeda dengan email Google yang dipakai |
| Perubahan tidak langsung muncul di browser lain | Muat ulang halaman. Realtime aktif setelah skrip SQL dijalankan. |

## Catatan

- Data di Supabase adalah salinan dari versi claude.ai per **9 Oktober 2026**. Setelah pindah, lakukan semua pengeditan di infraproject.online saja. Perubahan di versi claude.ai tidak ikut tersinkron.
- Tier gratis Supabase cukup untuk proyek ini. Project gratis yang **tidak dibuka sama sekali selama 7 hari** akan di-*pause* otomatis. Jika itu terjadi, masuk ke dashboard Supabase lalu klik **Restore**.
