import SwiftUI

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager.shared
    @StateObject private var logManager = QueryLogManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Trang chủ", systemImage: "shield.fill")
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
                    Label("Danh sách chặn", systemImage: "hand.raised.fill")
                }
                .tag(2)

            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Cài đặt", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// MARK: - Subview Dashboard
struct DashboardView: View {
    @ObservedObject private var dnsManager = DNSManager.shared
    @ObservedObject private var logManager = QueryLogManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Shield Hero Card
                    statusCard

                    // System VPN & DNS Management Card (Chuyên quản lý cấu hình hệ thống)
                    systemDnsManagementCard

                    // Configuration Section
                    configSection

                    // Quick Stats Cards
                    statsSection

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("NextDNS")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dnsManager.isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 90, height: 90)
                
                Image(systemName: dnsManager.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(dnsManager.isEnabled ? .green : .gray)
            }

            VStack(spacing: 4) {
                Text(dnsManager.isEnabled ? "ĐANG BẢO VỆ" : "CHƯA KÍCH HOẠT")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)

                Text(dnsManager.isEnabled ? dnsManager.liveStatusText : "Chạm công tắc để cấp quyền kích hoạt DNS")
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

            Toggle("", isOn: Binding(
                get: { dnsManager.isEnabled },
                set: { val in
                    if val {
                        dnsManager.enableDNS()
                    } else {
                        dnsManager.disableDNS()
                    }
                }
            ))
            .labelsHidden()
            .scaleEffect(1.2)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - System VPN / DNS Management Card
    private var systemDnsManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUẢN LÝ VPN & DNS HỆ THỐNG")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trạng thái Cấu hình iOS")
                            .font(.headline)
                        Text(dnsManager.isEnabled ? "Profile DNS đã được cài đặt vào hệ thống" : "Chưa có profile hoạt động")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(dnsManager.isEnabled ? Color.green : Color.orange)
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
                            Text("Kiểm tra hoặc gỡ bỏ DNS Profile trong Cài đặt chung")
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

                Divider()
                    .padding(.leading, 46)

                // Button to re-verify live status
                Button(action: { dnsManager.checkLiveConnection() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)

                        Text("Kiểm tra trạng thái máy chủ (test.nextdns.io)")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        if dnsManager.isVerifying {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(14)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Configuration Section
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CẤU HÌNH NEXTDNS")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Profile ID")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        TextField("Mặc định (Trống) hoặc ID của bạn", text: $dnsManager.nextDnsID)
                            .font(.system(size: 16, weight: .medium))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    if !dnsManager.nextDnsID.isEmpty {
                        Button(action: { dnsManager.nextDnsID = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(14)

                Divider()
                    .padding(.leading, 46)

                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.purple)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tên thiết bị gửi kèm")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        TextField("VD: iPhone của tôi", text: $dnsManager.deviceName)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .padding(14)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THỐNG KÊ HOẠT ĐỘNG")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            HStack(spacing: 12) {
                statCard(
                    title: "Domain Chặn",
                    value: "\(BlockList.getExactDomains().count + BlockList.getWildcards().count)",
                    sub: "Tích hợp sẵn",
                    icon: "hand.raised.fill",
                    iconColor: .red
                )

                statCard(
                    title: "Đã chặn",
                    value: "\(logManager.logs.filter { $0.isBlocked }.count)",
                    sub: "Truy vấn bị ngắt",
                    icon: "nosign",
                    iconColor: .orange
                )

                statCard(
                    title: "Giao thức",
                    value: dnsManager.selectedProtocol == .doh ? "DoH" : "DoT",
                    sub: "Mã hóa",
                    icon: "lock.shield.fill",
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
