import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var dnsManager = DNSManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Giao thức DNS")) {
                    Picker("Giao thức", selection: $dnsManager.selectedProtocol) {
                        ForEach(DNSProtocolType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                }

                Section(header: Text("Định danh NextDNS"), footer: Text("Bạn có thể đăng nhập vào https://my.nextdns.io để lấy ID cấu hình quản lý nâng cao.")) {
                    HStack {
                        Text("Profile ID")
                        Spacer()
                        TextField("ID cấu hình", text: $dnsManager.nextDnsID)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    HStack {
                        Text("Tên thiết bị")
                        Spacer()
                        TextField("Thiết bị", text: $dnsManager.deviceName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Giới thiệu")) {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("2.0 (Custom Build)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Trạng thái Extension")
                        Spacer()
                        Text("Sẵn sàng (NetworkExtension)")
                            .foregroundColor(.green)
                    }
                    Link(destination: URL(string: "https://my.nextdns.io")!) {
                        HStack {
                            Text("Mở Bảng điều khiển NextDNS")
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
