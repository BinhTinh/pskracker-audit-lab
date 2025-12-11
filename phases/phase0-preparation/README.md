# Phase 0: Preparation

## 📋 Mục đích

Phase này chuẩn bị môi trường cho lab: 

1. **Cài đặt dependencies** - Tất cả tools cần thiết
2. **Build PSKracker** - Compile từ source
3. **Generate target config** - Tạo BSSID và password hợp lệ

## 🔧 Scripts

| Script | Mô tả |
|--------|-------|
| `run. sh` | Main entry point, chạy tất cả scripts theo thứ tự |
| `01_install_dependencies.sh` | Cài đặt aircrack-ng, hostapd, dnsmasq, etc.  |
| `02_build_pskracker.sh` | Clone và build PSKracker |
| `03_generate_target.sh` | Tạo BSSID/SSID/Password cho Fake AP |

## 🚀 Cách chạy

```bash
# Từ project root
sudo ./lab.sh phase0

# Hoặc chạy trực tiếp
cd phases/phase0-preparation
sudo ./run.sh
