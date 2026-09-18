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
    
    private static let appGroupIdentifier = "group.com.nextdns.custom"
    private static let logsFileName = "dns_queries.json"
    private static let userDefaultsKey = "dns_query_logs_data"
    private static let maxLogEntries = 200

    @Published public var logs: [DNSQueryLogItem] = []

    public init() {
        loadLogs()
    }

    private static var sharedFileURL: URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return container.appendingPathComponent(logsFileName)
        }
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.first?.appendingPathComponent(logsFileName)
    }

    public func loadLogs() {
        // 1. Try reading from shared file
        if let fileURL = QueryLogManager.sharedFileURL,
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            DispatchQueue.main.async {
                self.logs = decoded
            }
            return
        }

        // 2. Try reading from App Group UserDefaults
        let defaults = UserDefaults(suiteName: QueryLogManager.appGroupIdentifier) ?? UserDefaults.standard
        if let data = defaults.data(forKey: QueryLogManager.userDefaultsKey),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            DispatchQueue.main.async {
                self.logs = decoded
            }
            return
        }

        // 3. Fallback: No logs yet, keep EMPTY! Do NOT load hardcoded sample items!
        DispatchQueue.main.async {
            self.logs = []
        }
    }

    public static func appendLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "UDP") {
        var currentLogs: [DNSQueryLogItem] = []

        // Read current logs from shared file or defaults
        if let fileURL = sharedFileURL,
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
            currentLogs = decoded
        } else {
            let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
            if let data = defaults.data(forKey: userDefaultsKey),
               let decoded = try? JSONDecoder().decode([DNSQueryLogItem].self, from: data) {
                currentLogs = decoded
            }
        }

        // Insert new entry at top
        let newEntry = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: queryType,
            clientProtocol: clientProtocol
        )
        currentLogs.insert(newEntry, at: 0)

        if currentLogs.count > maxLogEntries {
            currentLogs = Array(currentLogs.prefix(maxLogEntries))
        }

        // Save to file
        if let encoded = try? JSONEncoder().encode(currentLogs) {
            if let fileURL = sharedFileURL {
                try? encoded.write(to: fileURL, options: .atomic)
            }
            let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
            defaults.set(encoded, forKey: userDefaultsKey)
        }
    }

    public func addLog(domain: String, isBlocked: Bool, queryType: String = "A", clientProtocol: String = "UDP") {
        QueryLogManager.appendLog(domain: domain, isBlocked: isBlocked, queryType: queryType, clientProtocol: clientProtocol)
        loadLogs()
    }

    public func clearLogs() {
        if let fileURL = QueryLogManager.sharedFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let defaults = UserDefaults(suiteName: QueryLogManager.appGroupIdentifier) ?? UserDefaults.standard
        defaults.removeObject(forKey: QueryLogManager.userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: QueryLogManager.userDefaultsKey)

        DispatchQueue.main.async {
            self.logs = []
        }
    }
}
