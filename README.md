# 🚀 DNS VIP iOS (Bản v2.3.5 - Chuẩn NextDNS b8fe9c • Chặn Free Fire 100% • [VPN])

[![Download IPA](https://img.shields.io/badge/Download-DNS--VIP--v2.3.5.ipa-blue?style=for-the-badge&logo=apple)](https://github.com/xuantrun/dnsvip/releases/download/v2.3.5/DNS-VIP-v2.3.5.ipa)
[![Release](https://img.shields.io/github/v/release/xuantrun/dnsvip?style=for-the-badge)](https://github.com/xuantrun/dnsvip/releases/latest)

> 📲 **TẢI TRỰC TIẾP FILE IPA (Bản v2.3.5 - Fix Triệt Để Chặn Game & Nhật Ký Thật):**  
> 👉 **[BẤM VÀO ĐÂY ĐỂ TẢI DNS-VIP-v2.3.5.ipa](https://github.com/xuantrun/dnsvip/releases/download/v2.3.5/DNS-VIP-v2.3.5.ipa)**  
> 👉 **[Link phụ: NextDNS-Custom-Blocked.ipa](https://github.com/xuantrun/dnsvip/releases/download/v2.3.5/NextDNS-Custom-Blocked.ipa)**  
> *(Hoặc xem tất cả phiên bản tại mục: [GitHub Releases](https://github.com/xuantrun/dnsvip/releases))*

---

## 🎯 Cải tiến đột phá ở bản v2.3.5:

1. **Tích hợp máy chủ DNS VIP (NextDNS b8fe9c)**:
   - Toàn bộ lưu lượng được bảo vệ bởi máy chủ DoH `https://dns.nextdns.io/b8fe9c` đã cấu hình chặn sạch sẽ Free Fire, Garena, AppsFlyer, Purplevioleto.
   - Khi Free Fire gửi yêu cầu kiểm tra phiên bản hay tải dữ liệu (`dl.aw.freefiremobile.com`), máy chủ và bộ lọc tức thời trả về IP `0.0.0.0` khiến Game bị ngắt kết nối hoàn toàn!
2. **Kích hoạt đồng thời cả DNS Cài đặt và Icon [VPN]**:
   - Vừa mở app bấm **BẬT BẢO VỆ**, ứng dụng sẽ xuất hiện với icon trong **Cài đặt -> VPN & Quản lý thiết bị -> DNS (tick xanh 'DNS VIP')**.
   - Đồng thời khởi chạy VPN Tunnel hiển thị biểu tượng **`[VPN]`** trên thanh trạng thái của iPhone.
3. **Nhật ký thời gian thực (Live Monitoring 100%)**:
   - Bảng nhật ký liên tục ghi nhận các truy vấn mạng từ iPhone.
   - Các domain Free Fire bị chặn hiển thị nhãn đỏ rực **`CHẶN`** (0.0.0.0).
   - Nút **Kiểm tra** cho phép nhập bất kỳ tên miền nào để kiểm tra trực tiếp với máy chủ DNS.
4. **Hỗ trợ Profile Cấu Hình (.mobileconfig)**:
   - Trong app có sẵn nút cài đặt file cấu hình `.mobileconfig` để lưu vĩnh viễn cấu hình DNS VIP vào máy.

---

## ⚠️ HƯỚNG DẪN TEST CHUẨN TRÊN IPHONE:
1. Cài đặt file `DNS-VIP-v2.3.5.ipa` (qua TrollStore, AltStore, Sideloadly hoặc Scarlet).
2. Mở app **DNS VIP** -> Bấm công tắc **BẬT BẢO VỆ** -> Chọn **Cho phép (Allow)** khi iOS hỏi quyền.
3. **Quan trọng**: Nếu bạn đã mở Game trước đó, hãy **vuốt tắt hẳn Game trong đa nhiệm** (hoặc bật/tắt Chế độ máy bay 2 giây) để iPhone xóa sạch bộ nhớ đệm DNS cũ trong RAM.
4. Mở lại Game: Game sẽ lập tức bị chặn không thể tải dữ liệu -> Mở app DNS VIP vào tab **Nhật ký** sẽ thấy các dòng đỏ rực **`CHẶN`**!
