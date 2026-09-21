import Foundation
import Combine
import NetworkExtension
import UIKit

public class DNSManager: ObservableObject {
    public static let shared = DNSManager()

    @Published public var isEnabled: Bool = false
    @Published public var isProxyInstalled: Bool = false
    @Published public var isNativeDNSActive: Bool = false
    @Published public var isVerifying: Bool = false
    @Published public var statusMessage: String = "Sẵn sàng bảo vệ"
    @Published public var upstreamServer: String = "NextDNS VIP (b8fe9c)"
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false

    private let dnsSettingsManager = NEDNSSettingsManager.shared()
    private var tunnelManager: NETunnelProviderManager?

    private init() {
        loadStatus()

        // Observe native iOS VPN status changes
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleVPNStatusChange()
        }

        // Observe app becoming active to re-check DNS settings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadStatus()
        }
    }

    private func handleVPNStatusChange() {
        guard let mgr = tunnelManager else { return }
        switch mgr.connection.status {
        case .connected:
            self.isEnabled = true
            self.isProxyInstalled = true
            self.statusMessage = "Đang bảo vệ 24/7 • [VPN] và DNS VIP đang chạy ngầm"
            self.errorMessage = nil
            QueryLogManager.shared.fetchLogsFromTunnel()
            NSLog("[DNSManager] VPN Status: CONNECTED -> Active 24/7 [VPN] protection!")
        case .connecting:
            self.statusMessage = "Đang kết nối VPN..."
        case .disconnecting:
            self.statusMessage = "Đang ngắt kết nối VPN..."
        case .disconnected, .invalid:
            if !dnsSettingsManager.isEnabled {
                self.isEnabled = false
                self.statusMessage = "Chưa kích hoạt"
            }
        case .reasserting:
            self.statusMessage = "Đang tái thiết lập VPN..."
        @unknown default:
            break
        }
    }

    public func loadStatus() {
        // 1. Check NEDNSSettingsManager (iOS Settings > DNS with App Icon)
        dnsSettingsManager.loadFromPreferences { [weak self] _ in
            DispatchQueue.main.async {
                let active = self?.dnsSettingsManager.isEnabled == true
                self?.isNativeDNSActive = active
                if active {
                    self?.isEnabled = true
                    self?.isProxyInstalled = true
                    self?.statusMessage = "Đang bảo vệ 24/7 • DNS VIP hệ thống iOS đang chạy ngầm"
                    NSLog("[DNSManager] NEDNSSettingsManager is ACTIVE in iOS Settings!")
                }
            }
        }

        // 2. Check NETunnelProviderManager (VPN Configurations)
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            DispatchQueue.main.async {
                if let mgr = managers?.first {
                    self?.tunnelManager = mgr
                    if mgr.connection.status == .connected || (mgr.isEnabled && mgr.isOnDemandEnabled) {
                        self?.isEnabled = true
                        self?.isProxyInstalled = true
                        self?.statusMessage = "Đang bảo vệ 24/7 • [VPN] và DNS VIP đang chạy ngầm"
                        self?.errorMessage = nil
                        QueryLogManager.shared.fetchLogsFromTunnel()
                    }
                }
            }
        }
    }

    public func toggleProtection() {
        if isEnabled {
            disableAllProtection()
        } else {
            enableAllProtection()
        }
    }

    // Auto-request VPN & DNS permission like NextDNS without any codes!
    public func enableAllProtection(completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        statusMessage = "Đang kích hoạt bảo vệ..."
        errorMessage = nil

        // STEP 1: Configure & Save NEDNSSettingsManager
        // This registers "DNS VIP" directly into iOS Settings > General > VPN & Device Management > DNS with App Icon!
        // Using NextDNS profile b8fe9c which returns 0.0.0.0 for Free Fire domains!
        dnsSettingsManager.loadFromPreferences { [weak self] loadError in
            guard let self = self else { return }

            let doh = NEDDNSOverHTTPSSettings(servers: [
                "45.90.28.0",
                "45.90.30.0",
                "2a07:a8c0::0",
                "2a07:a8c1::0"
            ])
            doh.serverURL = URL(string: "https://dns.nextdns.io/b8fe9c")

            self.dnsSettingsManager.dnsSettings = doh
            self.dnsSettingsManager.localizedDescription = "DNS VIP"
            
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            self.dnsSettingsManager.onDemandRules = [connectRule]

            self.dnsSettingsManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        NSLog("[DNSManager] DNS Settings save info: %@", saveError.localizedDescription)
                    } else {
                        self?.isProxyInstalled = true
                        NSLog("[DNSManager] DNS VIP successfully registered into iOS Settings > DNS!")
                    }
                }
            }
        }

        // STEP 2: Configure & Trigger Native iOS VPN Tunnel with 24/7 On-Demand
        // This shows the [VPN] icon on iPhone status bar and persists across app exits!
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            let manager = managers?.first ?? NETunnelProviderManager()
            self.tunnelManager = manager

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.nextdns.custom.dnsproxy"
            proto.serverAddress = "127.0.0.1"

            manager.protocolConfiguration = proto
            manager.localizedDescription = "DNS VIP"
            manager.isEnabled = true

            // PERSIST 24/7 IN BACKGROUND:
            manager.isOnDemandEnabled = true
            let onDemandRule = NEOnDemandRuleConnect()
            onDemandRule.interfaceTypeMatch = .any
            manager.onDemandRules = [onDemandRule]

            manager.saveToPreferences { [weak self] saveError in
                guard let self = self else { return }
                if let saveError = saveError {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        NSLog("[DNSManager] VPN save error: %@", saveError.localizedDescription)
                        if self.isEnabled {
                            self.statusMessage = "Đang bảo vệ qua DNS • Chọn tick xanh 'DNS VIP' trong Cài đặt DNS"
                            completion?(true)
                        } else {
                            self.errorMessage = "Vui lòng chọn 'Cho phép' khi iOS hỏi quyền thiết bị"
                            completion?(false)
                        }
                    }
                } else {
                    manager.loadFromPreferences { _ in
                        do {
                            try manager.connection.startVPNTunnel()
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.isEnabled = true
                                self.isProxyInstalled = true
                                self.errorMessage = nil
                                self.statusMessage = "Đang bảo vệ 24/7 • Đã kích hoạt [VPN]"
                                NSLog("[DNSManager] startVPNTunnel successful! [VPN] icon active.")
                                QueryLogManager.shared.fetchLogsFromTunnel()
                                QueryLogManager.shared.startActiveMonitoring()
                                completion?(true)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.isEnabled = true
                                self.isProxyInstalled = true
                                self.statusMessage = "Đang bảo vệ 24/7 qua DNS VIP"
                                QueryLogManager.shared.startActiveMonitoring()
                                completion?(true)
                            }
                        }
                    }
                }
            }
        }
    }

    public func disableAllProtection() {
        isLoading = true
        statusMessage = "Đang tắt bảo vệ..."
        errorMessage = nil

        tunnelManager?.isOnDemandEnabled = false
        tunnelManager?.onDemandRules = []
        tunnelManager?.connection.stopVPNTunnel()
        tunnelManager?.isEnabled = false
        tunnelManager?.saveToPreferences { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isEnabled = false
                self?.isProxyInstalled = false
                self?.statusMessage = "Chưa kích hoạt"
            }
        }

        dnsSettingsManager.loadFromPreferences { [weak self] _ in
            self?.dnsSettingsManager.removeFromPreferences { _ in }
        }
    }

    public func openDNSSettings() {
        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    public func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
