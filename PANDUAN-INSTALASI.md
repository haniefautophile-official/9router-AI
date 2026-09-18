# OpenCode + 9Router di Termux (Android)

Panduan instalasi AI coding agent (OpenCode) yang terhubung ke provider AI gratis lewat 9Router, dijalankan di Termux (Android), lengkap dengan solusi masalah kompatibilitas Android 10/11.

## Daftar Isi

- [Prasyarat](#prasyarat)
- [1. Update Termux & Install Node.js](#1-update-termux--install-nodejs)
- [2. Install & Jalankan 9Router](#2-install--jalankan-9router)
- [3. Hubungkan Provider Gratis](#3-hubungkan-provider-gratis)
- [4. Buat API Key & Amankan Dashboard](#4-buat-api-key--amankan-dashboard)
- [5. Install OpenCode](#5-install-opencode)
- [6. Konfigurasi OpenCode ke 9Router](#6-konfigurasi-opencode-ke-9router)
- [7. Menjalankan OpenCode](#7-menjalankan-opencode)
- [8. Akses dari PC/Perangkat Lain](#8-akses-dari-pcperangkat-lain)
- [Troubleshooting](#troubleshooting)
- [Restart Setelah Termux Ditutup](#restart-setelah-termux-ditutup)
- [Disclaimer](#disclaimer)

## Prasyarat

- HP Android dengan [Termux](https://termux.dev) terpasang (disarankan dari F-Droid, bukan Play Store versi lama)
- Ruang disk kosong minimal 2-3 GB
- Koneksi internet stabil

## 1. Update Termux & Install Node.js

```bash
pkg update -y && pkg upgrade -y
pkg install -y nodejs-lts tar git
node --version   # pastikan >= v18
```

## 2. Install & Jalankan 9Router

[9Router](https://9router.com) adalah proxy open-source yang menghubungkan tool coding (OpenCode, Claude Code, dll) ke banyak provider AI sekaligus, dengan beberapa provider gratis tanpa API key.

```bash
npm install -g 9router
9router
```

Pilih **Web UI (Open in Browser)** dari menu yang muncul. Server akan berjalan di `http://localhost:20128`.

> Jalankan 9Router di session Termux terpisah dan biarkan tetap jalan — jangan di-stop selama ingin menggunakan OpenCode.

## 3. Hubungkan Provider Gratis

Buka dashboard 9Router di browser, masuk ke menu **Providers**, cari kategori **Free Tier Providers**, lalu pilih salah satu (contoh: **OpenCode Free**, tanpa autentikasi sama sekali).

Catat salah satu model ID yang tersedia, misalnya:
```
oc/muse-spark-1.3-contributor-free
```

> ⚠️ Perhatikan tier "Contributor Free" — biasanya berarti prompt & respons kamu boleh dipakai provider untuk training model mereka. Jangan gunakan untuk kode/data sensitif.

## 4. Buat API Key & Amankan Dashboard

1. Di menu **Endpoint & Key**, klik **Create Key**, salin key yang muncul.
2. Ganti password default dashboard (`123456`) sebelum mengakses dari perangkat lain di jaringan yang sama — 9Router akan menolak login password default dari alamat selain `localhost` demi keamanan.
   - Kalau perlu login remote sebelum sempat ganti password dari dalam Termux, restart 9Router dengan:
     ```bash
     INITIAL_PASSWORD=password-baru-kamu 9router
     ```

## 5. Install OpenCode

### ⚠️ Catatan kompatibilitas Android 10/11

Paket resmi `opencode-ai` dari npm **tidak berjalan langsung di Termux** karena belum ada build native untuk Android/Bionic. Ada dua wrapper komunitas:

| Wrapper | Cocok untuk | Catatan |
|---|---|---|
| [`@nemoobc/opencode-termux`](https://github.com/nemoobc/opencode-termux) | Android 12+ | Install via npm, tapi bisa gagal dengan error `SIGSYS` di Android 10/11 (binary musl-nya kena block seccomp) |
| [`HanSoBored/opencode-termux`](https://github.com/HanSoBored/opencode-termux) | Android 10/11 (dan versi lain) | Pakai loader glibc Termux + shim khusus untuk menangani seccomp `SIGSYS` |

Kalau install `@nemoobc/opencode-termux` dan muncul error `SIGSYS` saat smoke test, gunakan wrapper `HanSoBored` sebagai berikut:

```bash
# Install dependency glibc
pkg install -y glibc-repo
pkg install -y glibc glibc-runner
pkg install -y clang curl git

# Clone & install
git clone github.com/haniefautophile-official/9router-AI.git
cd 9router-AI
./install.sh

# Tambahkan ke PATH (sesuaikan .bashrc / .zshrc dengan shell kamu)
echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

opencode --version
```

> Sebelum menjalankan `install.sh` dari repo pihak ketiga manapun, baca dulu isinya — ini bukan repo resmi dari tim OpenCode.

## 6. Konfigurasi OpenCode ke 9Router

Simpan API key dari langkah 4 sebagai environment variable:

```bash
echo 'export NINEROUTER_API_KEY="paste-key-disini"' >> ~/.bashrc && source ~/.bashrc
```

Buat file config:

```bash
mkdir -p ~/.config/opencode && cat > ~/.config/opencode/opencode.json << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "9router": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "9Router",
      "options": {
        "baseURL": "http://localhost:20128/v1",
        "apiKey": "{env:NINEROUTER_API_KEY}"
      },
      "models": {
        "oc/muse-spark-1.3-contributor-free": {
          "name": "Muse Spark 1.3 (Free)"
        }
      }
    }
  },
  "model": "9router/oc/muse-spark-1.3-contributor-free"
}
EOF
```

## 7. Menjalankan OpenCode

**Mode TUI (terminal):**
```bash
mkdir -p ~/project-coba && cd ~/project-coba
opencode
```

**Mode Web (GUI berbasis browser):**
```bash
opencode web --port 4096 --hostname 0.0.0.0
```
Buka `http://localhost:4096` di browser HP, atau `http://<IP-lokal-HP>:4096` dari perangkat lain di jaringan yang sama.

## 8. Akses dari PC/Perangkat Lain

Jika mengakses Termux lewat SSH (misalnya MobaXterm) dan ingin membuka dashboard/web UI dari browser PC:

1. Cari IP lokal HP: `ip addr show wlan0` di Termux.
2. Buka `http://<IP-HP>:20128` (9Router) atau `http://<IP-HP>:4096` (OpenCode web) dari browser PC, dengan syarat HP dan PC berada di jaringan WiFi yang sama.
3. Kalau tidak berhasil (server hanya bind ke `localhost`), gunakan SSH port forwarding (local tunneling) dari klien SSH kamu.

> Catatan: mengakses lewat IP (bukan `localhost`) berarti halaman dianggap "Not secure" oleh browser modern, sehingga fitur seperti tombol "Copy/Salin" (Clipboard API) bisa gagal. Solusinya: select teks manual + `Ctrl+C`, atau whitelist origin lewat `chrome://flags/#unsafely-treat-insecure-origin-as-secure`.

## Troubleshooting

**Proses `opencode` memakai CPU tinggi terus-menerus / UI tidak responsif**
```bash
ps aux | grep -E '9router|opencode'
kill <PID>          # atau kill -9 <PID> kalau tidak mau berhenti
```
Jalankan ulang setelah itu. Storage yang hampir penuh (`df -h ~`) sering jadi penyebab proses "nyangkut".

**Storage Termux penuh**
```bash
df -h ~
termux-setup-storage   # izinkan akses storage HP
du -sh ~/storage/shared/*/ 2>/dev/null | sort -rh | head -15   # cari folder terbesar
```

**Cek port sebelum menjalankan servis baru**
```bash
sudo ss -tulpn | grep -E ':(20128|4096)'
```

## Restart Setelah Termux Ditutup

Proses akan berhenti setelah Termux/sesi SSH ditutup total. Untuk menyalakan ulang:

```bash
# Session 1
9router
# pilih Web UI atau Hide to Tray

# Session 2 (baru, jangan tutup session 1)
cd ~/project-coba && opencode web --port 4096 --hostname 0.0.0.0
```

## Disclaimer

- 9Router dan wrapper OpenCode-Termux yang disebut di sini adalah proyek **komunitas/pihak ketiga**, bukan produk resmi dari tim OpenCode atau provider AI yang bersangkutan.
- Selalu baca ToS masing-masing provider AI sebelum memakainya, terutama untuk tier gratis ("contributor free") yang biasanya menyertakan klausa penggunaan data untuk training.
- Jangan gunakan tier gratis untuk kode atau data yang bersifat sensitif/proprietary.
