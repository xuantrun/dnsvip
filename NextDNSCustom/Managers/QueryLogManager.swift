import Foundation

public struct DNSQueryLogItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let domain: String
    public let isBlocked: Bool
    public let timestamp: Date
    public let queryType: String
    public let clientProtocol: String
    
    public init(id: UUID = UUID(), domain: String, isBlocked: Bool, timestamp: Date = Date(), queryType: String = "A", clientProtocol: String = "UDP") {
        self.id = id
        self.domain = domain
        self.isBlocked = isBlocked
        self.timestamp = timestamp
        self.queryType = queryType
        self.clientProtocol = clientProtocol
    }
}

public class QueryLogManager: ObservableObject {
    public static let shared = QueryLogManager()
    
    private static let userDefaultsSuite = "group.com.nextdns.custom"
    private static let logsKey = "dns_query_logs_history"
    private static let maxLogEntries = 200

    @Published public var logs: [DNSQueryLogItem] = []

    public init() {
        loadLogs()
    }

    public func loadLogs() {
        let defaults = UserDefaults(suiteName: QueryLogManager.userDefaultsSuite) ?? UserDefaults.standard
        if let data = defaults.data(forKey: QueryLogManager.logsKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            DispatchQueue.main.async {
                self.logs = decoded
            }
        } else {
            // Populate initial sample/recent logs
            let sampleDomains = [
                ("dl.aw.freefiremobile.com", true),
                ("cdn-settings.appsflyersdk.com", true),
                ("apple.com", false),
                ("version.ffmax.purplevioleto.com", true),
                ("google.com", false),
                ("conversions.appsflyer.com", true),
                ("cloudflare.com", false),
                ("dl.verus.freefiremobile.com", true)
            ]
            var initLogs: [DNSQueryLogItem] = []
            for (idx, item) in sampleDomains.enumerated() {
                initLogs.append(DNSQueryLogItem(
                    domain: item.0,
                    isBlocked: item.1,
                    timestamp: Date().addingTimeInterval(Double(-idx * 15)),
                    queryType: "A",
                    clientProtocol: "DoH"
                ))
            }
            self.logs = initLogs
            saveLogsToDisk(initLogs)
        }
    }

    public static func appendLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "UDP") {
        let defaults = UserDefaults(suiteName: userDefaultsSuite) ?? UserDefaults.standard
        var current: [DNSQueryLogItem] = []
        if let data = defaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            current = decoded
        }
        
        let newLog = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: queryType,
            clientProtocol: clientProtocol
        )
        current.insert(newLog, at: 0)
        if current.count > maxLogEntries {
            current = Array(current.prefix(maxLogEntries))
        }

        if let encoded = try? JSONEncoder().encode(current) {
            defaults.set(encoded, forKey: logsKey)
        }
    }

    public func addLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "UDP") {
        QueryLogManager.appendLog(domain: domain, isBlocked: isBlocked, queryType: queryType, clientProtocol: clientProtocol)
        loadLogs()
    }

    public func clearLogs() {
        let defaults = UserDefaults(suiteName: QueryLogManager.userDefaultsSuite) ?? UserDefaults.standard
        defaults.removeObject(forKey: QueryLogManager.logsKey)
        DispatchQueue.main.async {
            self.logs = []
        }
    }

    private func saveLogsToDisk(_ items: [DNSQueryLogItem]) {
        let defaults = UserDefaults(suiteName: QueryLogManager.userDefaultsSuite) ?? UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: QueryLogManager.logsKey)
        }
    }
}
