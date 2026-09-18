import SwiftUI

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager.shared
    @StateObject private var logManager = QueryLogManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Protection Dashboard
            DashboardView()
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
            // Check status on appear
            dnsManager.loadStatus()
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @ObservedObject private var dnsManager = DNSManager.shared
    @ObservedObject private var logManager = QueryLogManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Hero Shield Card
                    heroStatusCard

                    // System Settings Verification Card
                    systemRegistrationCard

                    // Direct MobileConfig Profile Card (Shows in iOS Settings DNS list)
                    profileInstallCard

                    // Activity Statistics
                    statsSection

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("DNS VIP")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Hero Status Card
    private var heroStatusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dnsManager.isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: dnsManager.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .foregroundColor(dnsManager.isEnabled ? .green : .gray)
            }

            VStack(spacing: 4) {
                Text(dnsManager.isEnabled ? "ĐANG BẢO VỆ" : "CHƯA KÍCH HOẠT")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)

                Text(dnsManager.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if let err = dnsManager.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Power Toggle Button
            Button(action: {
                dnsManager.toggleProtection()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: dnsManager.isEnabled ? "power.circle.fill" : "power")
                        .font(.title3.bold())
                    Text(dnsManager.isEnabled ? "TẮT BẢO VỆ" : "BẬT BẢO VỆ & CHẶN NGAY")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(dnsManager.isEnabled ? Color.red.opacity(0.9) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
                .padding(.horizontal, 20)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - System Registration Card
    private var systemRegistrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CÀI ĐẶT PROXY DNS & DNS HỆ THỐNG")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trạng thái trong Cài đặt iOS")
                            .font(.headline)
                        Text(dnsManager.isProxyInstalled ? "Đã đăng ký 'DNS VIP' trong Cài đặt Proxy DNS" : "Bấm nút 'Bật bảo vệ' ở trên để cấp quyền vào iOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(dnsManager.isProxyInstalled ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                }
                .padding(14)

                Divider()
                    .padding(.leading, 46)

                // Button to open iOS System Settings
                Button(action: { dnsManager.openSystemSettings() }) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.indigo)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mở Cài đặt iOS (VPN & Quản lý thiết bị)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Xem và chọn tick xanh 'DNS VIP' trong mục DNS")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(14)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Direct MobileConfig Profile Card
    private var profileInstallCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CÀI ĐẶT HỒ SƠ (.MOBILECONFIG)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            Button(action: {
                ProfileGenerator.saveAndShareMobileConfig()
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.down.doc.fill")
                            .foregroundColor(.purple)
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Thêm Profile 'DNS VIP' vào máy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Tạo mục có biểu tượng bánh răng trong Cài đặt DNS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Activity Statistics
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THỐNG KÊ BẢO VỆ")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            HStack(spacing: 12) {
                statCard(
                    title: "Quy tắc Chặn",
                    value: "\(BlockList.getExactDomains().count + BlockList.getWildcards().count)",
                    sub: "Tích hợp sẵn",
                    icon: "hand.raised.fill",
                    iconColor: .red
                )

                statCard(
                    title: "Đã ngắt",
                    value: "\(logManager.logs.filter { $0.isBlocked }.count)",
                    sub: "Truy vấn bị chặn",
                    icon: "nosign",
                    iconColor: .orange
                )

                statCard(
                    title: "Chế độ",
                    value: "Local",
                    sub: "Chặn trực tiếp",
                    icon: "bolt.shield.fill",
                    iconColor: .green
                )
            }
        }
    }

    private func statCard(title: String, value: String, sub: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.medium))
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @ObservedObject private var dnsManager = DNSManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trạng thái Ứng dụng")) {
                    HStack {
                        Text("Tên ứng dụng")
                        Spacer()
                        Text("DNS VIP")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("2.3 (VIP Edition)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Cơ chế lọc")
                        Spacer()
                        Text("NetworkExtension Proxy")
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Máy chủ phân giải gốc (Upstream)")) {
                    HStack {
                        Text("Máy chủ an toàn")
                        Spacer()
                        Text("Cloudflare DoH / Quad9")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Yêu cầu tài khoản")
                        Spacer()
                        Text("Không cần (Tự động)")
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Hệ thống")) {
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
