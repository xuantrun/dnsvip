import SwiftUI

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager.shared
    @StateObject private var logManager = QueryLogManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: NextDNS Hero Protection Dashboard
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Bảo vệ", systemImage: "shield.fill")
                }
                .tag(0)

            // Tab 2: DNS Live Query Logs
            LogsView()
                .tabItem {
                    Label("Nhật ký", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .badge(logManager.blockedCount)
                .tag(1)

            // Tab 3: Filter & Blocklist
            BlocklistView()
                .tabItem {
                    Label("Bộ lọc", systemImage: "hand.raised.fill")
                }
                .tag(2)

            // Tab 4: System & Profile Settings
            SystemInfoView()
                .tabItem {
                    Label("Cài đặt", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .onAppear {
            dnsManager.loadStatus()
            logManager.loadLogs()
            logManager.fetchLogsFromTunnel()
        }
    }
}

// MARK: - NextDNS Signature Dashboard View
struct DashboardView: View {
    @ObservedObject private var dnsManager = DNSManager.shared
    @ObservedObject private var logManager = QueryLogManager.shared
    @Binding var selectedTab: Int
    @State private var pulseAnimation = false

    var body: some View {
        NavigationView {
            ZStack {
                // NextDNS Ambient Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Brand Bar
                        brandHeader
                            .padding(.top, 6)

                        // Center Hero Status & Toggle Card
                        heroStatusCard

                        // Live Metrics Panel
                        metricsPanel

                        // Live Query Ticker (Recent Intercepted DNS Queries)
                        recentQueriesCard

                        // Connection Specs Card
                        connectionSpecsCard

                        // iOS Quick Actions Card
                        quickActionsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Brand Header
    private var brandHeader: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color(red: 0.0, green: 0.8, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)

                    Image(systemName: "shield.checkerboard")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }

                Text("NextDNS")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)

                Text("VIP")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            Spacer()

            // Active Badge
            HStack(spacing: 5) {
                Circle()
                    .fill(dnsManager.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(dnsManager.isEnabled ? "ĐÃ BẬT" : "ĐÃ TẮT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Hero Status & NextDNS Power Switch
    private var heroStatusCard: some View {
        VStack(spacing: 20) {
            // Shield Graphic
            ZStack {
                // Pulse Ring when Active
                if dnsManager.isEnabled {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 16)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.08 : 0.98)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                }

                Circle()
                    .fill(dnsManager.isEnabled
                          ? LinearGradient(colors: [Color.green.opacity(0.18), Color.blue.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color.secondary.opacity(0.12), Color.secondary.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 100, height: 100)

                Image(systemName: dnsManager.isEnabled ? "bolt.shield.fill" : "shield.slash.fill")
                    .font(.system(size: 44))
                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)
            }
            .padding(.top, 10)

            // Status Headline
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(dnsManager.isEnabled ? "ĐÃ KẾT NỐI BẢO VỆ" : "CHƯA ĐƯỢC BẢO VỆ")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(dnsManager.isEnabled ? .green : .primary)

                    if dnsManager.isEnabled {
                        Text("[VPN]")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text(dnsManager.isEnabled
                     ? "Thiết bị đang được bảo vệ • Chặn quảng cáo, Game & Revoke"
                     : "Chạm vào công tắc bên dưới để bắt đầu bảo vệ thiết bị")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if let error = dnsManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
            }

            // NextDNS Signature Giant Toggle Switch
            HStack {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    dnsManager.toggleProtection()
                }) {
                    ZStack(alignment: dnsManager.isEnabled ? .trailing : .leading) {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(dnsManager.isEnabled
                                  ? LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.8, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 120, height: 58)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 5)
                            .overlay(
                                Image(systemName: dnsManager.isEnabled ? "power" : "power")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(dnsManager.isEnabled ? .blue : .gray)
                            )
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dnsManager.isEnabled)
                }
            }

            // Quick Status Pill
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(dnsManager.isEnabled ? .yellow : .secondary)
                    .font(.caption2)
                Text(dnsManager.isEnabled ? "Cloudflare Anycast • DoH & Packet Tunnel" : "Chưa kích hoạt cấu hình")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 6)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Metrics Panel (NextDNS Analytics Style)
    private var metricsPanel: some View {
        HStack(spacing: 10) {
            metricItem(title: "Đã chặn", count: "\(logManager.blockedCount)", color: .red, icon: "nosign")
            metricItem(title: "Cho phép", count: "\(logManager.allowedCount)", color: .green, icon: "checkmark.circle.fill")
            metricItem(title: "Tỷ lệ chặn", count: "\(logManager.blockRate)%", color: .blue, icon: "chart.pie.fill")
        }
    }

    private func metricItem(title: String, count: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Spacer()
            }
            Text(count)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: - Live Query Ticker Card
    private var recentQueriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("NHẬT KÝ TRUY VẤN TRỰC TIẾP")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: {
                    selectedTab = 1
                }) {
                    HStack(spacing: 2) {
                        Text("Tất cả (\(logManager.logs.count))")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }

            // Top 4 preview queries
            if logManager.logs.isEmpty {
                HStack {
                    Spacer()
                    Text("Chưa có truy vấn. Hãy lướt web hoặc mở game.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(logManager.logs.prefix(4)) { log in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(log.isBlocked ? Color.red : Color.green)
                                .frame(width: 6, height: 6)

                            Text(log.domain)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(log.isBlocked ? .red : .primary)
                                .lineLimit(1)

                            Spacer()

                            Text(log.category)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(log.isBlocked ? Color.red.opacity(0.12) : Color.blue.opacity(0.12))
                                .foregroundColor(log.isBlocked ? .red : .blue)
                                .cornerRadius(4)

                            Text(log.isBlocked ? "CHẶN" : "OK")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(log.isBlocked ? .red : .green)
                        }
                        .padding(.vertical, 3)
                        Divider()
                    }
                }
            }

            // Bottom Full Log Button
            Button(action: {
                selectedTab = 1
            }) {
                HStack {
                    Spacer()
                    Text("Xem toàn bộ nhật ký chi tiết →")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Connection Specs Card
    private var connectionSpecsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THÔNG TIN CẤU HÌNH BẢO VỆ")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                specRow(title: "Cấu hình", value: "DNS VIP (ff-anti-revoke)")
                Divider()
                specRow(title: "Giao thức", value: "DNS-over-HTTPS & Packet Tunnel")
                Divider()
                specRow(title: "Máy chủ upstream", value: "Cloudflare Anycast (1.1.1.1)")
                Divider()
                specRow(title: "Quy tắc lọc active", value: "\(BlockList.getExactDomains().count + BlockList.getWildcards().count) quy tắc")
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func specRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - iOS Quick Actions Card
    private var quickActionsCard: some View {
        VStack(spacing: 8) {
            Button(action: {
                dnsManager.openSystemSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                        .font(.headline)
                    Text("Mở Cài đặt iOS (VPN & Quản lý thiết bị)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            Button(action: {
                ProfileGenerator.saveAndShareMobileConfig()
            }) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundColor(.purple)
                        .font(.headline)
                    Text("Cài đặt Profile DNS (.mobileconfig)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @ObservedObject private var dnsManager = DNSManager.shared
    @ObservedObject private var logManager = QueryLogManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trạng thái bảo vệ")) {
                    HStack {
                        Text("Trạng thái")
                        Spacer()
                        Text(dnsManager.isEnabled ? "Đang bảo vệ" : "Chưa kích hoạt")
                            .foregroundColor(dnsManager.isEnabled ? .green : .secondary)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("VPN Identifier")
                        Spacer()
                        Text("com.nextdns.custom.dnsproxy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Dọn dẹp & Reset")) {
                    Button("Xóa toàn bộ nhật ký DNS") {
                        logManager.clearLogs()
                    }
                    .foregroundColor(.red)

                    Button("Khôi phục danh sách chặn mặc định") {
                        BlockList.resetToDefaults()
                    }
                    .foregroundColor(.orange)
                }

                Section(header: Text("Thông tin Ứng dụng")) {
                    HStack {
                        Text("Tên ứng dụng")
                        Spacer()
                        Text("NextDNS VIP")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("2.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Cài đặt")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
