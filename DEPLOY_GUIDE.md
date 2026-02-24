# Deploy Script Guide

## Cara Pakai Auto-Deploy

### Setup (Hanya 1x)

1. **Install lftp** (untuk upload otomatis):
   ```bash
   brew install lftp
   ```

2. **Edit SFTP credentials** di `deploy.sh` jika perlu (sudah diisi):
   - `SFTP_HOST`: Host Niagahoster
   - `SFTP_USER`: Username SFTP
   - `REMOTE_PATH`: Folder tujuan di server
   - `LOCAL_PATH`: Folder build lokal

### Cara Deploy (Setiap Update)

Cukup jalankan:
```bash
./deploy.sh
```

Script akan:
1. ✅ Build web dengan optimasi
2. ✅ Tanya password SFTP (sekali)
3. ✅ Upload semua file ke Niagahoster
4. ✅ Hapus file lama yang sudah tidak ada
5. ✅ Selesai!

### Tips
- Password akan ditanya setiap deploy (aman, tidak disimpan)
- Upload pertama lama (~5-10 menit), selanjutnya cepat (hanya file yang berubah)
- Bisa lihat progress upload real-time

### Troubleshooting

**Jika lftp belum terinstall:**
```bash
brew install lftp
```

**Jika Homebrew belum ada:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Upload manual (tanpa lftp):**
Gunakan SFTP extension di VS Code seperti sebelumnya.
