# 🚀 DNS VIP iOS (Tự động cấp quyền VPN & DNS • Chặn FreeFire)

[![Download IPA](https://img.shields.io/badge/Download-DNS--VIP--v2.3.4.ipa-blue?style=for-the-badge&logo=apple)](https://github.com/xuantrun/dnsvip/releases/download/v2.3.4/DNS-VIP-v2.3.4.ipa)
[![Release](https://img.shields.io/github/v/release/xuantrun/dnsvip?style=for-the-badge)](https://github.com/xuantrun/dnsvip/releases/latest)

> 📲 **TẢI TRỰC TIẾP FILE IPA (Bản v2.3.4 - Fix Chặn 0.0.0.0 Sinkhole & Nhật Ký Trực Tiếp):**  
> 👉 **[BẤM VÀO ĐÂY ĐỂ TẢI DNS-VIP-v2.3.4.ipa](https://github.com/xuantrun/dnsvip/releases/download/v2.3.4/DNS-VIP-v2.3.4.ipa)**  
> 👉 **[Link phụ: NextDNS-Custom-Blocked.ipa](https://github.com/xuantrun/dnsvip/releases/download/v2.3.4/NextDNS-Custom-Blocked.ipa)**  
> *(Hoặc xem tất cả phiên bản tại mục: [GitHub Releases](https://github.com/xuantrun/dnsvip/releases))*

---

## 🎯 Điểm nổi bật của bản cập nhật v2.3.4:

1. **Cơ chế Sinkhole Chặn 0.0.0.0 Cực Mạnh**: Khi Free Fire truy vấn các domain `dl.aw.freefiremobile.com`, `version.ffmax`, hệ thống sẽ lập tức trả về IP `0.0.0.0` ngay trong máy, khiến Game không thể kết nối server và bị chặn hoàn toàn.
2. **Tách biệt định tuyến DNS 198.18.0.2**: Đảm bảo toàn bộ gói tin DNS của tất cả ứng dụng & Game đều đi qua bộ lọc Packet Tunnel mà không bị kẹt hay bypass.
3. **Nhật ký thời gian thực (Live Logs)**: Ghi nhận trực tiếp từng truy vấn bị chặn với nhãn đỏ **`CHẶN`** và nhãn xanh **`CHO PHÉP`**.
4. **Giao diện NextDNS Hero**: Thiết kế công tắc nguồn to bản, màn hình thống kê trực quan.

---

## ⚠️ LƯU Ý KHI TEST BỘ LỌC CHẶN GAME:
- Vì iOS có bộ nhớ đệm DNS (**DNS Cache**): Nếu bạn vừa mở Game trước khi bật VPN, iPhone vẫn còn lưu IP cũ của game trong RAM.
- 👉 **Cách test chuẩn**: Bật VPN trên App -> Vuốt tắt hẳn Game (hoặc bật/tắt Chế độ máy bay 2 giây) -> Mở lại Game để iPhone gửi truy vấn DNS mới -> Game sẽ bị chặn ngay lập tức và Nhật ký trong app sẽ nhảy thông báo!
