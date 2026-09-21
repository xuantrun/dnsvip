import Foundation
import Combine
import NetworkExtension

public struct DNSQueryLogItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let domain: String
    public let isBlocked: Bool
    public let timestamp: Date
    public let queryType: String
    public let clientProtocol: String

    public init(id: UUID = UUID(), domain: String, isBlocked: Bool, timestamp: Date = Date(), queryType: String = "A", clientProtocol: String = "DoH/VPN") {
        self.id = id
        self.domain = domain
        self.isBlocked = isBlocked
        self.timestamp = timestamp
        self.queryType = queryType
        self.clientProtocol = clientProtocol
    }

    public var category: String {
        let lower = domain.lowercased()
        if lower.contains("freefire") || lower.contains("purplevioleto") {
            return "Free Fire"
        } else if lower.contains("appsflyer") {
            return "AppsFlyer"
        } else if lower.contains("garena") || lower.contains("grtc") {
            return "Garena"
        } else if lower.contains("akamai") || lower.contains("listdl") || lower.contains("gcloud") {
            return "CDN Chặn"
        } else if lower.contains("google") || lower.contains("apple") || lower.contains("cloudflare") {
            return "Hợp lệ"
        }
        return isBlocked ? "Quy tắc VIP" : "Truy vấn chung"
    }
}

public class QueryLogManager: ObservableObject {
    public static let shared = QueryLogManager()

    private static let appGroupIdentifier = "group.com.nextdns.custom"
    private static let logsFileName = "dns_queries.json"
    private static let localStoreKey = "dns_vip_permanent_logs_v3"
    private static let userDefaultsKey = "dns_query_logs_data"
    private static let maxLogEntries = 300

    @Published public var logs: [DNSQueryLogItem] = []

    private var monitoringTimer: Timer?
    private var domainIndex = 0
    private let monitoredDomains = [
        "dl.aw.freefiremobile.com",
        "version.ffmax.purplevioleto.com",
        "conversions.appsflyer.com",
        "client.us.freefiremobile.com",
        "apple.com",
        "google.com",
        "intlsdk.iegg.garena.com",
        "inapps.appsflyer.com"
    ]

    public var blockedCount: Int {
        logs.filter { $0.isBlocked }.count
    }

    public var allowedCount: Int {
        logs.filter { !$0.isBlocked }.count
    }

    public var blockRate: Int {
        guard !logs.isEmpty else { return 0 }
        return Int((Double(blockedCount) / Double(logs.count)) * 100.0)
    }

    public init() {
        loadLogs()
        if logs.isEmpty {
            seedInitialLogs()
        }
    }

    private static var sharedFileURL: URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return container.appendingPathComponent(logsFileName)
        }
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.first?.appendingPathComponent(logsFileName)
    }

    public func loadLogs() {
        var loadedList: [DNSQueryLogItem]? = nil

        // 1. Read from permanent local UserDefaults
        if let data = UserDefaults.standard.data(forKey: QueryLogManager.localStoreKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data),
           !decoded.isEmpty {
            loadedList = decoded
        }

        // 2. Try reading from App Group file if available
        if let fileURL = QueryLogManager.sharedFileURL,
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data),
           !decoded.isEmpty {
            if loadedList == nil {
                loadedList = decoded
            } else {
                loadedList = mergeLists(primary: loadedList!, incoming: decoded)
            }
        }

        // 3. Try reading from App Group UserDefaults
        let defaults = UserDefaults(suiteName: QueryLogManager.appGroupIdentifier) ?? UserDefaults.standard
        if let data = defaults.data(forKey: QueryLogManager.userDefaultsKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data),
           !decoded.isEmpty {
            if loadedList == nil {
                loadedList = decoded
            } else {
                loadedList = mergeLists(primary: loadedList!, incoming: decoded)
            }
        }

        if let validList = loadedList {
            DispatchQueue.main.async {
                self.logs = validList
            }
        }
    }

    // MARK: - IPC Fetch from active VPN Packet Tunnel
    public func fetchLogsFromTunnel() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            guard let manager = managers?.first,
                  let session = manager.connection as? NETunnelProviderSession,
                  session.status == .connected else {
                return
            }

            guard let reqData = "get_logs".data(using: .utf8) else { return }

            do {
                try session.sendProviderMessage(reqData) { responseData in
                    guard let data = responseData,
                          let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) else {
                        return
                    }
                    DispatchQueue.main.async {
                        self?.mergeIncomingLogs(decoded)
                    }
                }
            } catch {
                NSLog("[QueryLogManager] sendProviderMessage get_logs error: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Active Background Network Verification
    public func startActiveMonitoring() {
        guard monitoringTimer == nil else { return }
        checkNextDomain()

        DispatchQueue.main.async {
            self.monitoringTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.checkNextDomain()
            }
        }
    }

    private func checkNextDomain() {
        let domain = monitoredDomains[domainIndex % monitoredDomains.count]
        domainIndex += 1
        testDomainOnline(domain: domain) { _ in }
    }

    public func testDomainOnline(domain: String, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "https://dns.nextdns.io/b8fe9c/dns-query?name=\(domain)") else {
            completion?(false)
            return
        }

        var req = URLRequest(url: url)
        req.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 2.5

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let localBlocked = BlockList.isBlocked(domain: domain)
                self?.addLog(domain: domain, isBlocked: localBlocked, queryType: "A", clientProtocol: "DoH")
                completion?(localBlocked)
                return
            }

            var isBlocked = false
            if let answer = json["Answer"] as? [[String: Any]] {
                for ans in answer {
                    if let ip = ans["data"] as? String, (ip == "0.0.0.0" || ip == "::") {
                        isBlocked = true
                        break
                    }
                }
            } else if let status = json["Status"] as? Int, status == 3 {
                isBlocked = true
            }

            if BlockList.isBlocked(domain: domain) {
                isBlocked = true
            }

            self.addLog(domain: domain, isBlocked: isBlocked, queryType: "A", clientProtocol: "DoH")
            completion?(isBlocked)
        }.resume()
    }

    public static func appendLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "DoH/VPN") {
        let newEntry = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: queryType,
            clientProtocol: clientProtocol
        )

        var currentLogs: [DNSQueryLogItem] = []
        if let data = UserDefaults.standard.data(forKey: localStoreKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            currentLogs = decoded
        }

        currentLogs.insert(newEntry, at: 0)
        if currentLogs.count > maxLogEntries {
            currentLogs = Array(currentLogs.prefix(maxLogEntries))
        }

        saveToDisk(items: currentLogs)
    }

    public func addLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "DoH/VPN") {
        let newEntry = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: queryType,
            clientProtocol: clientProtocol
        )

        DispatchQueue.main.async {
            self.logs.insert(newEntry, at: 0)
            if self.logs.count > QueryLogManager.maxLogEntries {
                self.logs = Array(self.logs.prefix(QueryLogManager.maxLogEntries))
            }
            QueryLogManager.saveToDisk(items: self.logs)
        }
    }

    public func mergeIncomingLogs(_ incoming: [DNSQueryLogItem]) {
        let merged = mergeLists(primary: self.logs, incoming: incoming)
        self.logs = merged
        QueryLogManager.saveToDisk(items: merged)
    }

    private func mergeLists(primary: [DNSQueryLogItem], incoming: [DNSQueryLogItem]) -> [DNSQueryLogItem] {
        var seen = Set<String>()
        var result: [DNSQueryLogItem] = []

        for item in incoming + primary {
            let key = "\(item.domain)_\(Int(item.timestamp.timeIntervalSince1970))_\(item.isBlocked)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }

        result.sort { $0.timestamp > $1.timestamp }
        if result.count > QueryLogManager.maxLogEntries {
            result = Array(result.prefix(QueryLogManager.maxLogEntries))
        }
        return result
    }

    private static func saveToDisk(items: [DNSQueryLogItem]) {
        guard let encoded = try? JSONEncoder().encode(items) else { return }

        UserDefaults.standard.set(encoded, forKey: localStoreKey)

        if let fileURL = sharedFileURL {
            try? encoded.write(to: fileURL, options: .atomic)
        }

        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        defaults.set(encoded, forKey: userDefaultsKey)
    }

    public func seedInitialLogs() {
        let samples: [(String, Bool)] = [
            ("dl.aw.freefiremobile.com", true),
            ("conversions.appsflyer.com", true),
            ("dns.nextdns.io", false),
            ("version.ffmax.purplevioleto.com", true),
            ("client.us.freefiremobile.com", true),
            ("apple.com", false),
            ("inapps.appsflyer.com", true),
            ("google.com", false)
        ]

        var now = Date()
        var items: [DNSQueryLogItem] = []
        for (domain, blocked) in samples {
            now = now.addingTimeInterval(-Double.random(in: 4...25))
            items.append(DNSQueryLogItem(
                domain: domain,
                isBlocked: blocked,
                timestamp: now,
                queryType: "A",
                clientProtocol: "DoH/VPN"
            ))
        }
        self.logs = items
        QueryLogManager.saveToDisk(items: items)
    }

    public func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }

        UserDefaults.standard.removeObject(forKey: QueryLogManager.localStoreKey)
        UserDefaults.standard.removeObject(forKey: QueryLogManager.userDefaultsKey)

        let defaults = UserDefaults(suiteName: QueryLogManager.appGroupIdentifier) ?? UserDefaults.standard
        defaults.removeObject(forKey: QueryLogManager.userDefaultsKey)

        if let fileURL = QueryLogManager.sharedFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }

        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            guard let manager = managers?.first,
                  let session = manager.connection as? NETunnelProviderSession,
                  session.status == .connected,
                  let clearReq = "clear_logs".data(using: .utf8) else {
                return
            }
            try? session.sendProviderMessage(clearReq) { _ in }
        }
    }
}
