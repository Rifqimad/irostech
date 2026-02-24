# Panduan Update & Deploy Website CBRN4

Halo! Ini adalah panduan lengkap untuk mengupdate dan deploy website CBRN4 ke production.

## Setup Awal (Hanya sekali)

### 1. Clone Project
```bash
git clone https://github.com/Rifqimad/irostech.git
cd irostech
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Install Tool Deploy

#### **Option A: lftp (Recommended untuk Mac/Linux)**

**macOS:**
```bash
brew install lftp
```

**Linux/Ubuntu:**
```bash
sudo apt install lftp
```

**Windows - menggunakan Chocolatey:**
```powershell
# Install Chocolatey dulu (di PowerShell sebagai Administrator):
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Lalu install lftp:
choco install lftp
```

**Windows - menggunakan WSL (Ubuntu):**
```bash
# Di WSL Ubuntu terminal:
sudo apt install lftp
```

#### **Option B: VS Code SFTP Extension (Mudah untuk Windows)**

Kalau tidak mau install lftp, pakai VS Code SFTP:

1. Install extension "SFTP" (by Natizyskunk) di VS Code
2. Config sudah ada di `.vscode/sftp.json`
3. **Untuk deploy:**
   - Build web: `flutter build web --release`
   - Right-click folder `build/web` → **SFTP: Upload Active Folder**
   - Masukkan password FTP

### 4. Dapatkan Password FTP
Password FTP: `Hexacopter12345!`
(Simpan untuk digunakan saat deploy)

---

## Workflow Update Website (Sehari-hari)

### Step 1: Pull Kode Terbaru
**Selalu jalankan ini sebelum mulai coding:**

#### **Opsi A: Auto-deploy dengan script (Mac/Linux/Windows WSL)**
```bash
./deploy.sh
```
Password: `Hexacopter12345!`

#### **Opsi B: Manual dengan VS Code SFTP (Mudah untuk Windows)**
```bash
# 1. Build web
flutter build web --release

# 2. Upload via VS Code:
# - Right-click folder build/web
# - Pilih "SFTP: Upload Active Folder"
# - Masukkan password: Hexacopter12345!
``rowser:
```bash
flutter run -d chrome
```

Atau test di web-server:
```bash
flutter run -d web-server --web-port 8081
```

Buka browser: `http://localhost:8081`

### Step 3: Commit & Push Perubahan
**Setelah selesai coding:**
```bash
git add .
git commit -m "Deskripsi perubahan kamu"
git push origin main
```

### Step 4: Deploy ke Production
**Update website live:**
```bash
./deploy.sh
```

Saat diminta password, masukkan: `Hexacopter12345!`

Script akan otomatis:
- ✅ Build web dengan optimasi

**macOS:**
```bash
brew install lftp
```

**Windows:** Pakai VS Code SFTP Extension (lebih mudah):
1. Install extension "SFTP" di VS Code
2. Build: `flutter build web --release`
3. Upload via extension (Right-click `build/web` → SFTP: Upload)one!** Website terupdate di:
https://化学生物放射性核.irostech.com/pusatoleh-olehbandung/

---

## Troubleshooting

### Error "lftp: command not found"
Install lftp:
```bash
brew install lftp
```

### Error "Permission denied: ./deploy.sh"
Berikan execute permission:
```bash
chmod +x deploy.sh
```

### Error "Login failed" saat deploy
Pastikan password FTP benar: `Hexacopter12345!`

### Web masih menampilkan versi lama
- Hard refresh browser: `Cmd+Shift+R` (Mac) atau `Ctrl+Shift+R` (Windows)
- Clear cache browser

---

## Tips Kolaborasi

1. **Selalu `git pull` dulu** sebelum mulai coding
2. **Test di local** sebelum push ke GitHub
3. **Commit message yang jelas** - apa yang diubah
4. **Deploy hanya jika sudah yakin** kode berfungsi dengan baik
5. **Komunikasi dengan tim** sebelum deploy perubahan besar

---

## File Penting

- `lib/` - Source code Dart/Flutter
- `web/` - Template web (index.html, manifest, icons)
- `deploy.sh` - Script auto-deploy
- `build_web_optimized.sh` - Script build optimal
- `.vscode/sftp.json` - Config FTP

---

## Kontak

Kalau ada masalah atau pertanyaan:
- Tanya di grup
- Cek dokumentasi: `DEPLOY_GUIDE.md`

---

**Happy coding! 🚀**
