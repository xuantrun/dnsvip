import SwiftUI

struct LogsView: View {
    @ObservedObject private var logManager = QueryLogManager.shared
    @State private var filterSelection = 0 // 0: All, 1: Blocked, 2: Allowed
    @State private var searchText = ""
    @State private var showingTestSheet = false
    @State private var testDomainInput = "dl.aw.freefiremobile.com"
    private let liveTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Stat Cards
                summaryCards
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Segmented Filter
                Picker("Lọc", selection: $filterSelection) {
                    Text("Tất cả (\(logManager.logs.count))").tag(0)
                    Text("Đã chặn (\(blockedCount))").tag(1)
                    Text("Cho phép (\(allowedCount))").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Logs List
                if filteredLogs.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "shield.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Chưa có nhật ký truy vấn nào")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Các truy vấn DNS từ game và ứng dụng sẽ hiển thị trực tiếp tại đây.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredLogs) { log in
                            logRow(log)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .searchable(text: $searchText, prompt: "Tìm tên miền...")
            .navigationTitle("Nhật ký DNS")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingTestSheet = true }) {
                        Label("Kiểm tra", systemImage: "play.circle.fill")
                            .font(.footnote)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { logManager.clearLogs() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(logManager.logs.isEmpty)
                }
            }
            .sheet(isPresented: $showingTestSheet) {
                testQuerySheet
            }
            .onAppear {
                logManager.loadLogs()
            }
            .onReceive(liveTimer) { _ in
                logManager.loadLogs()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var blockedCount: Int {
        logManager.logs.filter { $0.isBlocked }.count
    }

    private var allowedCount: Int {
        logManager.logs.filter { !$0.isBlocked }.count
    }

    private var filteredLogs: [DNSQueryLogItem] {
        var list = logManager.logs
        if filterSelection == 1 {
            list = list.filter { $0.isBlocked }
        } else if filterSelection == 2 {
            list = list.filter { !$0.isBlocked }
        }

        if !searchText.isEmpty {
            list = list.filter { $0.domain.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    private func logRow(_ log: DNSQueryLogItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(log.isBlocked ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: log.isBlocked ? "hand.raised.fill" : "checkmark.shield.fill")
                    .foregroundColor(log.isBlocked ? .red : .green)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.domain)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(log.isBlocked ? .red : .primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(log.queryType)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)

                    Text(log.clientProtocol)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption2)

                    Text(formatTimestamp(log.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if log.isBlocked {
                Text("BLOCKED")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            } else {
                Text("ALLOWED")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            statBadge(title: "Đã chặn", count: "\(blockedCount)", color: .red, icon: "nosign")
            statBadge(title: "Được phép", count: "\(allowedCount)", color: .green, icon: "checkmark.circle")
            statBadge(title: "Tổng truy vấn", count: "\(logManager.logs.count)", color: .blue, icon: "chart.bar.fill")
        }
    }

    private func statBadge(title: String, count: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Spacer()
            }
            Text(count)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var testQuerySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Kiểm tra thử domain chặn")) {
                    TextField("Nhập domain cần test", text: $testDomainInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button("Gửi truy vấn kiểm tra") {
                        let blocked = BlockList.isBlocked(domain: testDomainInput)
                        logManager.addLog(domain: testDomainInput, isBlocked: blocked, queryType: "A", clientProtocol: "DoH")
                        showingTestSheet = false
                    }
                }
                
                Section(header: Text("Tên miền gợi ý test nhanh")) {
                    Button("dl.aw.freefiremobile.com (Chặn)") {
                        testDomainInput = "dl.aw.freefiremobile.com"
                    }
                    Button("conversions.appsflyer.com (Chặn)") {
                        testDomainInput = "conversions.appsflyer.com"
                    }
                    Button("google.com (Cho phép)") {
                        testDomainInput = "google.com"
                    }
                }
            }
            .navigationTitle("Test Bộ Lọc")
            .navigationBarItems(trailing: Button("Đóng") {
                showingTestSheet = false
            })
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
