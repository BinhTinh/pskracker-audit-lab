# 🔐 PSKracker Audit Lab

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange?logo=ubuntu)
![Shell](https://img.shields.io/badge/Shell-Bash-green?logo=gnu-bash)
![License](https://img.shields.io/badge/License-MIT-blue)
![CVE](https://img.shields.io/badge/CVE-2012--4366-red)

## 📋 Giới thiệu

Đồ án nghiên cứu **lỗ hổng bảo mật CVE-2012-4366** - lỗ hổng entropy yếu trong thuật toán tạo mật khẩu mặc định của router Belkin. 

### 🎯 Mục tiêu

- Hiểu rõ cơ chế tạo mật khẩu mặc định dựa trên MAC address
- Thực hành setup môi trường kiểm toán không dây
- Minh họa PSKracker trong việc phát hiện mật khẩu yếu
- Đề xuất biện pháp khắc phục

## 🏗️ Kiến trúc Lab

```
┌─────────────────────────────────────────────────────────────────┐
│                     UBUNTU 24.04 HOST                           │
│                                                                 │
│   ┌─────────────────────┐        ┌─────────────────────┐       │
│   │   USB REALTEK       │        │   INTEL AX201       │       │
│   │   (Target AP)       │◄──────►│   (Auditor)         │       │
│   │                     │  WiFi  │                     │       │
│   │   • hostapd         │        │   • Monitor Mode    │       │
│   │   • Belkin BSSID    │        │   • airodump-ng     │       │
│   │   • PSKracker pwd   │        │   • Capture         │       │
│   └─────────────────────┘        └─────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ⚙️ Yêu cầu

### Hardware
- 2 Wireless adapters (1 hỗ trợ AP mode, 1 hỗ trợ Monitor mode)
- 1 Smartphone/Laptop làm test client

### Software
- Ubuntu 24.04 LTS
- aircrack-ng suite
- hostapd, dnsmasq
- PSKracker

## 🚀 Cách sử dụng

```bash
# Clone repo
git clone https://github.com/BinhTinh/pskracker-audit-lab.git
cd pskracker-audit-lab

# Xem status
sudo ./lab.sh status

# Chạy từng phase
sudo ./lab.sh phase0    # Cài đặt dependencies
sudo ./lab.sh phase1    # Kiểm tra hardware
sudo ./lab.sh phase2    # Setup Target AP
sudo ./lab.sh phase3    # Capture handshake
sudo ./lab.sh phase4    # Crack PSK
sudo ./lab.sh phase5    # Tạo báo cáo

# Hoặc chạy full
sudo ./lab.sh full

# Cleanup
sudo ./lab.sh cleanup
```

## 📁 Cấu trúc thư mục

```
pskracker-audit-lab/
├── lab.sh                    # Main orchestrator
├── config/
│   ├── lab.conf              # Main configuration
│   └── templates/            # Config templates
├── lib/                      # Shared libraries
│   ├── core.sh
│   ├── hardware.sh
│   └── network.sh
├── phases/                   # Execution phases
│   ├── phase0-preparation/
│   ├── phase1-hardware/
│   ├── phase2-target-ap/
│   ├── phase3-recon/
│   ├── phase4-attack/
│   └── phase5-reporting/
├── data/                     # Runtime data
│   ├── captures/
│   ├── handshakes/
│   ├── wordlists/
│   └── results/
├── logs/                     # All logs
└── reports/                  # Generated reports
```

## 📖 Phases

| Phase | Mô tả |
|-------|-------|
| 0 | Cài đặt dependencies, build PSKracker |
| 1 | Phát hiện và verify wireless hardware |
| 2 | Setup Fake Belkin AP với password từ PSKracker |
| 3 | Scan và capture WPA2 handshake |
| 4 | Crack PSK sử dụng PSKracker wordlist |
| 5 | Tạo báo cáo audit |

## ⚠️ Disclaimer

Dự án này chỉ dành cho mục đích **nghiên cứu và giáo dục**.  Chỉ sử dụng trên thiết bị bạn sở hữu hoặc có quyền kiểm tra. 

## 📄 License

MIT License - Xem file [LICENSE](LICENSE) để biết thêm chi tiết. 
