# 🔐 PSKracker Audit Lab - Kiểm toán An ninh Mạng không dây

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange?logo=ubuntu)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-Active-success)

## 📋 Giới thiệu

Đồ án nghiên cứu **lỗ hổng bảo mật cấp độ cấu hình** trong cơ chế tạo mật khẩu mặc định của các router không dây (Belkin, Netgear). Dự án này áp dụng phương pháp **SOC Audit & Security Assessment**, tập trung vào:

- ✅ Phân tích thuật toán tạo khóa tất định
- ✅ Xác minh lỗ hổng CVE-2012-4366
- ✅ Mô phỏng môi trường kiểm toán không dây
- ✅ Đề xuất biện pháp khắc phục theo chuẩn quốc tế

---

## 🎯 Mục tiêu Học tập

| Mục tiêu | Mô tả |
|----------|-------|
| **Kỹ thuật** | Hiểu rõ lỗ hổng entropy yếu trong PRNG |
| **Thực hành** | Setup môi trường kiểm toán với hostapd + aircrack-ng |
| **Phân tích** | Phân biệt lỗ hổng giao thức vs lỗ hổng cấu hình |
| **Bảo mật** | Áp dụng hardening theo PCI-DSS, ISO 27001 |

---

## 🏗️ Kiến trúc Hệ thống

┌─────────────────────────────────────────────────────────────┐ │ MÁY UBUNTU 24.04 (Dual Setup) │ │ │ │ ┌──────────────────┐ ┌──────────────────┐ │ │ │ wlx... (USB) │ │ wlo1 (Intel) │ │ │ │ CARD YẾU │ │ CARD MẠNH │ │ │ │ │ │ │ │ │ │ ROLE: TARGET │ │ ROLE: AUDITOR │ │ │ │ (Fake Belkin AP)│◄────────────►│ (Attacker) │ │ │ │ │ Wireless │ │ │ │ │ hostapd │ Packets │ airodump-ng │ │ │ │ dnsmasq │ │ pskracker │ │ │ │ BSSID: 08:86:3B │ │ Monitor Mode │ │ │ └──────────────────┘ └──────────────────┘ │ │ │ │ 💡 Lý do phân vai này: │ │ - USB card yếu chỉ cần phát beacon (không tốn tài nguyên)│ │ - Intel card mạnh → scan nhanh, bắt packet hiệu quả │ └─────────────────────────────────────────────────────────────┘



---

## ⚙️ Yêu cầu Hệ thống

### Phần cứng:
- ✅ **2 Wireless Adapters**:
  - **Card 1 (Built-in Intel AX201)**: Làm Auditor (Monitor mode)
  - **Card 2 (USB Realtek)**: Làm Target (AP mode)
- ✅ Ubuntu 24.04 LTS (dual boot hoặc máy ảo với USB passthrough)

### Phần mềm:
```bash
# Sẽ được cài tự động qua script
- aircrack-ng
- hostapd
- dnsmasq
- iw, wireless-tools
- Python 3
- PSKracker (build từ source)
