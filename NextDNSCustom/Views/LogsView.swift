import SwiftUI

struct LogsView: View {
    @ObservedObject private var logManager = QueryLogManager.shared
    @State private var filterSelection = 0 // 0: All, 1: Blocked, 2: Allowed
    @State private var searchText = ""
    @State private var showingTestSheet = false
    @State private var testDomainInput = "dl.aw.freefiremobile.com"
    @State private var selectedLogItem: DNSQueryLogItem? = nil

    private let liveTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Live Status Banner
                    liveStatusHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Summary Stat Cards
                    summaryCards
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    // Filter Picker
                    Picker("Lọc", selection: $filterSelection) {
                        Text("Tất cả (\(logManager.logs.count))").tag(0)
                        Text("Đã chặn (\(logManager.blockedCount))").tag(1)
                        Text("Cho phép (\(logManager.allowedCount))").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Logs List
                    if filteredLogs.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(filteredLogs) { log in
                                logRow(log)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedLogItem = log
                                    }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Tìm tên miền hoặc danh mục...")
            .navigationTitle("Nhật ký DNS")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingTestSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.magnifyingglass")
                            Text("Kiểm tra")
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
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
            .sheet(item: $selectedLogItem) { log in
                logDetailSheet(log)
            }
            .onAppear {
                logManager.loadLogs()
                logManager.fetchLogsFromTunnel()
            }
            .onReceive(liveTimer) { _ in
                logManager.fetchLogsFromTunnel()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Live Status Header
    private var liveStatusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text("GHI NHẬN THỜI GIAN THỰC")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.green)

            Spacer()

            Text("\(filteredLogs.count) truy vấn")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }

    // MARK: - Filtered Logs
    private var filteredLogs: [DNSQueryLogItem] {
        var list = logManager.logs
        if filterSelection == 1 {
            list = list.filter { $0.isBlocked }
        } else if filterSelection == 2 {
            list = list.filter { !$0.isBlocked }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.domain.lowercased().contains(query) ||
                $0.category.lowercased().contains(query)
            }
        }
        return list
    }

    // MARK: - Log Row
    private func logRow(_ log: DNSQueryLogItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Left Status Icon
            ZStack {
                Circle()
                    .fill(log.isBlocked ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: log.isBlocked ? "hand.raised.fill" : "checkmark.shield.fill")
                    .foregroundColor(log.isBlocked ? .red : .green)
                    .font(.system(size: 14, weight: .bold))
            }

            // Middle Domain & Details
            VStack(alignment: .leading, spacing: 3) {
                Text(log.domain)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(log.isBlocked ? .red : .primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(log.category)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(log.isBlocked ? Color.red.opacity(0.12) : Color.blue.opacity(0.12))
                        .foregroundColor(log.isBlocked ? .red : .blue)
                        .cornerRadius(4)

                    Text(log.clientProtocol)
                        .font(.system(size: 10, weight: .medium))
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

            // Right Status Badge
            if log.isBlocked {
                Text("CHẶN")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            } else {
                Text("CHO PHÉP")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Summary Cards
    private var summaryCards: some View {
        HStack(spacing: 8) {
            statBadge(title: "Đã chặn", count: "\(logManager.blockedCount)", color: .red, icon: "nosign")
            statBadge(title: "Cho phép", count: "\(logManager.allowedCount)", color: .green, icon: "checkmark.circle.fill")
            statBadge(title: "Tỷ lệ", count: "\(logManager.blockRate)%", color: .blue, icon: "chart.pie.fill")
        }
    }

    private func statBadge(title: String, count: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption2)
                Spacer()
            }
            Text(count)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }

            Text("Chưa có nhật ký truy vấn")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Khi bạn lướt web hoặc mở game, mọi truy vấn DNS sẽ hiển thị trực tiếp tại đây.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button(action: {
                logManager.seedInitialLogs()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("Tải nhật ký kiểm tra mẫu")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.top, 6)

            Spacer()
        }
    }

    // MARK: - Test Query Sheet
    private var testQuerySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Kiểm tra thử domain")) {
                    TextField("Nhập domain (VD: dl.aw.freefiremobile.com)", text: $testDomainInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: {
                        logManager.testDomainOnline(domain: testDomainInput) { _ in }
                        showingTestSheet = false
                    }) {
                        HStack {
                            Spacer()
                            Text("Gửi truy vấn kiểm tra")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }

                Section(header: Text("Tên miền kiểm tra nhanh")) {
                    Button("dl.aw.freefiremobile.com (Chặn Game FF)") {
                        testDomainInput = "dl.aw.freefiremobile.com"
                    }
                    Button("conversions.appsflyer.com (Chặn Tracker)") {
                        testDomainInput = "conversions.appsflyer.com"
                    }
                    Button("client.us.freefiremobile.com (Chặn Game FF)") {
                        testDomainInput = "client.us.freefiremobile.com"
                    }
                    Button("google.com (Cho phép)") {
                        testDomainInput = "google.com"
                    }
                    Button("apple.com (Cho phép)") {
                        testDomainInput = "apple.com"
                    }
                }
            }
            .navigationTitle("Kiểm Tra Bộ Lọc")
            .navigationBarItems(trailing: Button("Đóng") {
                showingTestSheet = false
            })
        }
    }

    // MARK: - Log Detail Sheet
    private func logDetailSheet(_ log: DNSQueryLogItem) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin truy vấn")) {
                    HStack {
                        Text("Tên miền")
                        Spacer()
                        Text(log.domain)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(log.isBlocked ? .red : .primary)
                    }

                    HStack {
                        Text("Trạng thái")
                        Spacer()
                        Text(log.isBlocked ? "ĐÃ CHẶN (BLOCKED)" : "CHO PHÉP (ALLOWED)")
                            .font(.headline)
                            .foregroundColor(log.isBlocked ? .red : .green)
                    }

                    HStack {
                        Text("Phân loại")
                        Spacer()
                        Text(log.category)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Giao thức")
                        Spacer()
                        Text(log.clientProtocol)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Thời gian")
                        Spacer()
                        Text(formatFullTimestamp(log.timestamp))
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Thao tác")) {
                    Button(action: {
                        UIPasteboard.general.string = log.domain
                        selectedLogItem = nil
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Sao chép tên miền")
                        }
                    }

                    if log.isBlocked {
                        Button(action: {
                            var exacts = BlockList.getExactDomains()
                            exacts.removeAll { $0.lowercased() == log.domain.lowercased() }
                            BlockList.saveExactDomains(exacts)
                            selectedLogItem = nil
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Bỏ chặn tên miền này")
                            }
                            .foregroundColor(.green)
                        }
                    } else {
                        Button(action: {
                            var exacts = BlockList.getExactDomains()
                            exacts.append(log.domain)
                            BlockList.saveExactDomains(exacts)
                            selectedLogItem = nil
                        }) {
                            HStack {
                                Image(systemName: "nosign")
                                Text("Thêm vào danh sách chặn")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Chi tiết truy vấn")
            .navigationBarItems(trailing: Button("Xong") {
                selectedLogItem = nil
            })
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatFullTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}
