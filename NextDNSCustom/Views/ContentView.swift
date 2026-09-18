import SwiftUI

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager.shared
    @StateObject private var logManager = QueryLogManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Protection Dashboard (NextDNS Style)
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Bảo vệ", systemImage: "shield.fill")
                }
                .tag(0)

            // Tab 2: Logs (Check log xem đang chặn gì)
            LogsView()
                .tabItem {
                    Label("Nhật ký", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .badge(logManager.logs.filter { $0.isBlocked }.count)
                .tag(1)

            // Tab 3: Blocklist
            BlocklistView()
                .tabItem {
                    Label("Bộ lọc", systemImage: "hand.raised.fill")
                }
                .tag(2)

            // Tab 4: System Settings
            SystemInfoView()
                .tabItem {
                    Label("Hệ thống", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .onAppear {
            dnsManager.loadStatus()
            logManager.loadLogs()
        }
    }
}

// MARK: - Dashboard View (NextDNS Official Design)
struct DashboardView: View {
    @ObservedObject private var dnsManager = DNSManager.shared
    @ObservedObject private var logManager = QueryLogManager.shared
    @Binding var selectedTab: Int

    var body: some View {
        NavigationView {
            List {
                // Section 1: NextDNS Hero Switch & Status Card
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(dnsManager.isEnabled ? Color.green : Color.gray)
                                    .frame(width: 12, height: 12)

                                Text(dnsManager.isEnabled ? "ĐÃ BẬT" : "ĐÃ TẮT")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { dnsManager.isEnabled },
                                set: { _ in dnsManager.toggleProtection() }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }

                        Text(dnsManager.isEnabled
                             ? "Thiết bị này đang sử dụng DNS VIP với bộ lọc chặn game & quảng cáo."
                             : "Thiết bị này chưa được bảo vệ. Bật công tắc để bắt đầu chặn.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let error = dnsManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        // Big Action Button
                        Button(action: {
                            dnsManager.toggleProtection()
                        }) {
                            HStack(spacing: 8) {
                                if dnsManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: dnsManager.isEnabled ? "power.circle.fill" : "bolt.shield.fill")
                                        .font(.headline)
                                }
                                Text(dnsManager.isEnabled ? "TẮT BẢO VỆ" : "BẬT BẢO VỆ & KÍCH HOẠT [VPN]")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(dnsManager.isEnabled ? Color.red.opacity(0.85) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Section 2: Connection & Protocol Details (NextDNS Style)
                Section(header: Text("THÔNG TIN KẾT NỐI")) {
                    HStack {
                        Text("Trạng thái VPN")
                        Spacer()
                        if dnsManager.isEnabled {
                            HStack(spacing: 4) {
                                Text("[VPN]")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                Text("Đã kết nối")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Chưa kết nối")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Giao thức")
                        Spacer()
                        Text("Packet Tunnel • DoH")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Máy chủ Upstream")
                        Spacer()
                        Text("Cloudflare (1.1.1.1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Quy tắc lọc")
                        Spacer()
                        Text("\(BlockList.getExactDomains().count + BlockList.getWildcards().count) quy tắc")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }

                // Section 3: Live Log Summary Card
                Section(header: Text("NHẬT KÝ HOẠT ĐỘNG")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Truy vấn đã chặn")
                                .font(.headline)
                            Text("\(logManager.logs.filter { $0.isBlocked }.count) tên miền bị ngắt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            selectedTab = 1
                        }) {
                            Text("Xem chi tiết")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: {
                        selectedTab = 1
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .foregroundColor(.indigo)
                            Text("Mở bảng theo dõi thời gian thực")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // Section 4: iOS Settings Direct Shortcuts
                Section(header: Text("CÀI ĐẶT HỆ THỐNG IOS")) {
                    Button(action: {
                        dnsManager.openSystemSettings()
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("Mở Cài đặt iOS (VPN & Quản lý thiết bị)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    Button(action: {
                        ProfileGenerator.saveAndShareMobileConfig()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(.purple)
                            Text("Cài đặt Profile DNS (.mobileconfig)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("DNS VIP")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
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
                        Text("2.3.3 (NextDNS Pure Edition)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Cơ chế")
                        Spacer()
                        Text("NEPacketTunnelProvider")
                            .foregroundColor(.blue)
                    }
                }

                Section(header: Text("Cài đặt")) {
                    Button(action: { dnsManager.openSystemSettings() }) {
                        HStack {
                            Text("Mở Cài đặt iOS")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Hệ thống")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
