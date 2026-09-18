import SwiftUI

struct ContentView: View {
    @StateObject private var dnsManager = DNSManager.shared
    @State private var showingBlocklist = false
    @State private var showingSettings = false
    @State private var showingAddDomain = false
    @State private var newDomainText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Shield Hero Card
                    statusCard

                    // Configuration Section
                    configSection

                    // Quick Actions / Stats
                    statsSection

                    // Blocklist Summary Button
                    blocklistCard

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("NextDNS")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingBlocklist) {
                BlocklistView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dnsManager.isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: dnsManager.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 54, height: 54)
                    .foregroundColor(dnsManager.isEnabled ? .green : .gray)
            }

            VStack(spacing: 4) {
                Text(dnsManager.isEnabled ? "ĐÃ BẬT" : "ĐÃ TẮT")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(dnsManager.isEnabled ? .green : .secondary)

                Text(dnsManager.isEnabled 
                     ? (dnsManager.nextDnsID.isEmpty ? "Đang sử dụng Anycast NextDNS & Chặn theo danh sách" : "Kết nối tới Profile: \(dnsManager.nextDnsID)")
                     : "Thiết bị chưa được mã hóa và lọc DNS")
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
        .padding(.vertical, 24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
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
            Text("BẢO MẬT & CHẶN")
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
                    title: "Giao thức",
                    value: dnsManager.selectedProtocol == .doh ? "DoH" : "DoT",
                    sub: "HTTPS / TLS",
                    icon: "lock.shield.fill",
                    iconColor: .green
                )
            }
        }
    }

    private func statCard(title: String, value: String, sub: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.headline)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.medium))
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Blocklist Card
    private var blocklistCard: some View {
        Button(action: { showingBlocklist = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundColor(.orange)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Quản lý danh sách chặn")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Xem các domain Game, Tracking & SDK bị khóa")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.footnote.bold())
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
}
