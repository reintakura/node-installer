# node-installer

Script untuk install Node.js portable di macOS, tanpa sudo / admin.
Helper scripts that install portable Node.js on macOS, no sudo needed.

## macOS

Install Node.js LTS terbaru (official build dari nodejs.org) ke home folder (`~/.local/portable-node`). Tidak perlu sudo, admin, Homebrew, atau Xcode.

```bash
curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/install.sh | bash
```

Pilih versi tertentu / pin a version:

```bash
curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/install.sh | NODE_VERSION=22.11.0 bash
```

Setelah itu buka terminal baru (atau `source ~/.zshrc`), lalu cek:

```bash
node -v && npm -v
```

## Uninstall / cleanup

```bash
curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/uninstall.sh | bash
```

Menghapus Node.js, semua paket `npm i -g`, symlink di `~/.local/bin`, baris `prefix` di `~/.npmrc`, dan baris PATH di `~/.zshrc` / `~/.bash_profile` (backup disimpan sebagai `.bak`).

## Catatan / Notes

- Tanpa sudo: semua file ada di `~/.local/portable-node`, command `node`, `npm`, `npx` (dan `corepack` kalau ada) di-link ke `~/.local/bin`.
- Default: LTS terbaru. Jalankan ulang script untuk update ke LTS terbaru, versi lama otomatis dihapus.
- `NODE_VERSION=x.y.z` untuk versi tertentu. `NODE_INSTALL_PREFIX` untuk lokasi lain.
- `npm i -g <paket>` jalan tanpa sudo: global prefix diset ke `~/.local/portable-node/npm-global` (hanya kalau `~/.npmrc` belum punya `prefix`).
- Download diverifikasi dengan sha256 dari `SHASUMS256.txt` resmi.
- Node.js 25+ tidak lagi menyertakan `corepack`. Kalau perlu: `npm i -g corepack`.
