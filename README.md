# 🚀 NextDNS Custom iOS (Blocked FreeFire & Tracking)

[![Download IPA](https://img.shields.io/badge/Download-NextDNS--Custom--Blocked.ipa-blue?style=for-the-badge&logo=apple)](https://github.com/xuantrun/dnsvip/releases/download/v2.2.0/NextDNS-Custom-Blocked.ipa)
[![Release](https://img.shields.io/github/v/release/xuantrun/dnsvip?style=for-the-badge)](https://github.com/xuantrun/dnsvip/releases/latest)

> 📲 **TẢI TRỰC TIẾP FILE IPA (Bản v2.2.0 Mới Nhất):**  
> 👉 **[BẤM VÀO ĐÂY ĐỂ TẢI NEXTDNS-CUSTOM-BLOCKED.IPA (v2.2.0)](https://github.com/xuantrun/dnsvip/releases/download/v2.2.0/NextDNS-Custom-Blocked.ipa)**  
> *(Hoặc xem tất cả phiên bản tại mục: [GitHub Releases](https://github.com/xuantrun/dnsvip/releases))*

---

## 🎯 Tính năng nổi bật

- **Cấp phép như NextDNS App Store**: Tích hợp `NEDNSSettingsManager` chuẩn của Apple. Khi gạt công tắc, iOS sẽ hiện popup cấp quyền cấu hình DNS hệ thống.
- **Mã hóa DoH & DoT**: Hỗ trợ chuẩn DNS-over-HTTPS và DNS-over-TLS.
- **Chặn cục bộ siêu tốc (NetworkExtension `NEDNSProxyProvider`)**: Bắt toàn bộ truy vấn DNS, nếu phát hiện domain nằm trong danh sách chặn sẽ trả về `NXDOMAIN / 0.0.0.0` ngay lập tức.
- **Quản lý danh sách chặn trong app**: Tìm kiếm, thêm/xóa domain và wildcard trực tiếp trên giao diện SwiftUI.

---

## 🛡️ Danh sách Domain & Wildcard đã nhúng sẵn

### 1. Tên miền khớp chính xác (Exact Domains)
```text
cdn-settings.appsflyersdk.com
dl.aw.freefiremobile.com
dl-us-production.freefiremobile.com
dl.verus.freefiremobile.com
version.ffmax.purplevioleto.com
client.us.freefiremobile.com
intlsdk.iegg.garena.com
cloudctrl.gcloudsdk.com
glcs.listdl.com
dl.ctlin.freefiremobile.com
dl.cvs.freefiremobile.com
dl.gcp.freefiremobile.com
conversions.appsflyer.com
inapps.appsflyer.com
dl-sg-production.freefiremobile.com
gin.freefiremobile.com
launches.appsflyer.com
dl.castle.freefiremobile.com
dl.dir.freefiremobile.com
client.common.freefiremobile.com
bdversion.ggbluefox.com
freefiremobile-a.akamaihd.net
csoversea.stronghold.freefiremobile.com
dl.listdl.com
ff.dr.grtc.garenanow.com
dl.tata.freefiremobile.com
ff.sdk.grtc.garenanow.com
gcloudcs.com
```

### 2. Tên miền Wildcard (`*.`)
```text
*.dl.lost.freefiremobile.com
*.akamai.net
*.gopapi.io
*.local.com
*.ip.local.com
*.freefiremax.freefiremobile.com
*.rankguide.sea.freefiremobile.com
*.rankgui.sea.freefiremobile.com
*.rankred.sea.freefiremobile.com
*.rankguide.oprn.freefiremobile.com
*.hotro.ff.garena.com
*.dl.cfn.freefiremobile.com
*.dl.ar.freefiremobile.com
*.a1818.dscw154.akamai.net
*.dl.local.freefiremobile.com
*.dl.iphack.freefiremobile.com
*.gs.live.kg.garena.vn
```

---

## 📲 Hướng dẫn Cài đặt lên iPhone

1. Tải file **`NextDNS-Custom-Blocked.ipa`** theo link ở trên.
2. Cài đặt vào máy bằng **TrollStore**, **AltStore**, **SideStore** hoặc **Sideloadly**.
3. Mở app lên -> Gạt công tắc kích hoạt -> iOS sẽ hỏi:  
   *`"NextDNS" Would Like to Add DNS Configurations`* -> Chọn **Allow (Cho phép)**.
4. Mọi truy vấn kết nối tới các domain game/tracking trên sẽ bị chặn hoàn toàn!
