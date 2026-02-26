#!/bin/bash
# Auto-deploy script untuk Niagahoster
# Usage: ./deploy.sh

set -e  # Stop jika ada error

echo "🚀 Starting deployment process..."
echo ""

# Step 1: Build optimized web
echo "📦 Building web app..."
./build_web_optimized.sh

echo ""
echo "📤 Preparing to upload to Niagahoster..."
echo ""

# FTP Configuration - From Niagahoster Panel
FTP_HOST="153.92.9.252"
FTP_USER="u739922356"
FTP_PASS="Hexacopter12345!"
REMOTE_PATH="/public_html/pusatoleh-olehbandung"
LOCAL_PATH="build/web"

# Cek apakah lftp terinstall
if command -v lftp &> /dev/null; then
    echo "Using lftp for upload..."
    
    # Upload dengan lftp (lebih cepat & reliable)
    lftp -u "$FTP_USER,$FTP_PASS" ftp://"$FTP_HOST" <<EOF
set ftp:ssl-allow no
mirror --reverse --delete --verbose --exclude-glob .DS_Store "$LOCAL_PATH" "$REMOTE_PATH"
bye
EOF

else
    echo "⚠️  lftp not found. Using standard FTP..."
    echo "Install lftp for better performance: brew install lftp"
    echo ""
    
    # Fallback: Manual FTP upload
    echo "Please upload files manually:"
    echo "1. Connect to FTP: $FTP_HOST"
    echo "2. Username: $FTP_USER"
    echo "3. Upload folder: $LOCAL_PATH/* → $REMOTE_PATH/"
    echo ""
    echo "Or install lftp and run this script again."
    exit 1
fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 Visit: https://化学生物放射性核.irostech.com/pusatoleh-olehbandung/"
