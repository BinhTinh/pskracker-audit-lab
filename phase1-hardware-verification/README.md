# Phase 1: Hardware Verification - Kiểm tra Phần cứng

## 🎯 Mục tiêu Phase

Phase này xác minh rằng hệ thống của bạn có đủ phần cứng và capabilities để chạy toàn bộ lab.

### Yêu cầu:
- ✅ **2 wireless adapters** (1 cho AP, 1 cho Monitor)
- ✅ Ít nhất 1 card hỗ trợ **AP mode**
- ✅ Ít nhất 1 card hỗ trợ **Monitor mode**
- ✅ Driver nl80211 hoặc mac80211

---

## 📋 Scripts trong Phase này

| Script | Mô tả | Output |
|--------|-------|--------|
| `01_check_hardware.sh` | Phát hiện và phân tích tất cả wireless interfaces | `logs/hardware_report_*. txt` |
| `02_verify_capabilities.sh` | Xác minh AP mode & Monitor mode support | Terminal + logs |

---

## 🚀 Cách chạy

### Script 1: Kiểm tra Hardware

```bash
cd ~/pskracker-audit-lab/phase1-hardware-verification
sudo bash 01_check_hardware.sh
```

**Kết quả:**
- Hiển thị danh sách tất cả wireless interfaces
- Phân tích capabilities (Supported modes, Frequencies, Ciphers)
- Tạo file report chi tiết trong `logs/`
- Đề xuất vai trò cho từng card (AP vs Monitor)

---

### Script 2: Verify Capabilities

```bash
sudo bash 02_verify_capabilities. sh
```

**Kết quả:**
- Kiểm tra từng interface có hỗ trợ AP mode không
- Kiểm tra từng interface có hỗ trợ Monitor mode không
- Cảnh báo nếu có processes xung đột (NetworkManager, wpa_supplicant)
- Tạo bảng compatibility matrix

---

## 📊 Kết quả mong đợi

Sau khi chạy xong Phase 1, bạn sẽ có:

### 1. Hardware Report
File: `logs/hardware_report_<timestamp>.txt`

```
HARDWARE VERIFICATION REPORT
Generated: 2025-12-03 16:15:00

Number of interfaces: 2

Interface: wlo1
  PHY: phy0
  MAC: 70:1a:b8:45:95:11
  Type: managed
  Supported Modes:
    * IBSS
    * managed
    * AP
    * AP/VLAN
    * monitor
    * P2P-client
    * P2P-GO
  
Interface: wlx90de80390f17
  PHY: phy1
  MAC: 90:de:80:39:0f:17
  Type: managed
  Supported Modes:
    * IBSS
    * managed
    * AP
    * AP/VLAN
    * monitor
```

### 2. Role Assignment

```
KHUYẾN NGHỊ VAI TRÒ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Interface: wlo1 (Intel)
  → ROLE: AUDITOR/ATTACKER
  → Mode: Monitor mode
  → Lý do: Card mạnh, scan nhanh, dual-band

Interface: wlx90de80390f17 (USB)
  → ROLE: TARGET (Fake AP)
  → Mode: AP mode
  → Lý do: Chỉ cần phát beacon, không cần tốc độ cao
```

---

## ✅ Checklist Phase 1

- [ ] Đã phát hiện ít nhất 2 wireless interfaces
- [ ] Ít nhất 1 card hỗ trợ AP mode
- [ ] Ít nhất 1 card hỗ trợ Monitor mode
- [ ] Đã tạo hardware report trong `logs/`
- [ ] Đã chụp screenshot terminal output
- [ ] Đã hiểu rõ vai trò của từng card

---

## 🔧 Troubleshooting

### Vấn đề 1: Chỉ phát hiện 1 interface

**Nguyên nhân:** USB adapter chưa được cắm hoặc driver chưa load

**Giải pháp:**
```bash
# Kiểm tra USB devices
lsusb | grep -i wireless

# Kiểm tra kernel modules
lsmod | grep 80211

# Load driver thủ công (nếu cần)
sudo modprobe rtl8xxxu  # Cho Realtek
```

---

### Vấn đề 2: Interface không hỗ trợ AP mode

**Nguyên nhân:** Driver cũ hoặc chipset không tương thích

**Giải pháp:**
```bash
# Cập nhật driver
sudo apt install linux-firmware

# Hoặc compile driver từ GitHub
# (Xem hướng dẫn của nhà sản xuất)
```

---

### Vấn đề 3: NetworkManager chiếm quyền interface

**Triệu chứng:** Không thể set monitor mode hoặc AP mode

**Giải pháp:**
```bash
# Tạm thời unmanage interface
sudo nmcli device set wlo1 managed no
```

---

## 📸 Screenshots cần chụp cho báo cáo

1. ✅ Output của `01_check_hardware.sh` (danh sách interfaces)
2.  ✅ Nội dung file `hardware_report_*. txt`
3. ✅ Output của `02_verify_capabilities. sh` (compatibility matrix)
4. ✅ Output của `iw list` cho cả 2 cards

---

## 🎯 Bước tiếp theo

Sau khi hoàn thành Phase 1:

```bash
cd ../phase2-fake-ap-setup
```

Đọc `README.md` trong Phase 2 để tiếp tục! 

---

## 📚 Tài liệu tham khảo

- [iw documentation](https://wireless.wiki. kernel.org/en/users/documentation/iw)
- [nl80211 driver](https://wireless.wiki.kernel.org/en/developers/documentation/nl80211)
- [Airmon-ng usage](https://www.aircrack-ng.org/doku.php? id=airmon-ng)
