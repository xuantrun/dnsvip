import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var dnsManager = DNSManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin Ứng dụng")) {
                    HStack {
                        Text("Tên ứng dụng")
                        Spacer()
                        Text("DNS VIP")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("2.3.0 (VIP Edition)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Trạng thái Bảo vệ")
                        Spacer()
                        Text(dnsManager.isEnabled ? "Đang bật" : "Đã tắt")
                            .foregroundColor(dnsManager.isEnabled ? .green : .red)
                    }
                }

                Section(header: Text("Máy chủ Phân giải Gốc (Upstream)")) {
                    HStack {
                        Text("Máy chủ DNS")
                        Spacer()
                        Text("Cloudflare DoH (1.1.1.1)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Mã hóa Truy vấn")
                        Spacer()
                        Text("DNS-over-HTTPS (DoH)")
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Cài đặt Hệ thống iOS")) {
                    Button(action: { dnsManager.openSystemSettings() }) {
                        HStack {
                            Text("Mở Cài đặt iOS (VPN & Quản lý thiết bị)")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarItems(trailing: Button("Đóng") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
