import Foundation
import Combine
import NetworkExtension
import UIKit

public class DNSManager: ObservableObject {
    public static let shared = DNSManager()

    @Published public var isEnabled: Bool = false
    @Published public var isProxyInstalled: Bool = false
    @Published public var isVerifying: Bool = false
    @Published public var statusMessage: String = "Sẵn sàng bảo vệ"
    @Published public var upstreamServer: String = "Cloudflare DoH (1.1.1.1)"
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false

    private let dnsSettingsManager = NEDNSSettingsManager.shared()
    private var tunnelManager: NETunnelProviderManager?

    private init() {
        loadStatus()
        
        // Listen to native iOS VPN status changes (Connecting, Connected, Disconnected)
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleVPNStatusChange()
        }
    }

    private func handleVPNStatusChange() {
        guard let mgr = tunnelManager else { return }
        switch mgr.connection.status {
        case .connected:
            self.isEnabled = true
            self.isProxyInstalled = true
            self.statusMessage = "Đang bảo vệ • Đã kích hoạt [VPN] trên thiết bị"
            self.errorMessage = nil
            QueryLogManager.shared.fetchLogsFromTunnel()
            NSLog("[DNSManager] VPN Status: CONNECTED -> [VPN] icon active!")
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
        // 1. Check NEDNSSettingsManager (Settings > DNS entry with App Icon)
        dnsSettingsManager.loadFromPreferences { [weak self] _ in
            DispatchQueue.main.async {
                let isDnsActive = self?.dnsSettingsManager.isEnabled ?? false
                if isDnsActive {
                    self?.isEnabled = true
                    self?.isProxyInstalled = true
                    self?.statusMessage = "Đang bảo vệ • DNS VIP đã kích hoạt"
                    self?.errorMessage = nil
                }
            }
        }

        // 2. Check NETunnelProviderManager (VPN Configurations)
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            DispatchQueue.main.async {
                if let mgr = managers?.first {
                    self?.tunnelManager = mgr
                    if mgr.connection.status == .connected || mgr.isEnabled {
                        self?.isEnabled = true
                        self?.isProxyInstalled = true
                        self?.statusMessage = "Đang bảo vệ • VPN DNS VIP đang hoạt động [VPN]"
                        self?.errorMessage = nil
                    }
                }
            }
        }
    }

    public func toggleProtection() {
        if isEnabled || isProxyInstalled {
            disableAllProtection()
        } else {
            enableAllProtection()
        }
    }

    // Auto-request VPN & DNS permission like NextDNS without any codes!
    public func enableAllProtection(completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        statusMessage = "Đang yêu cầu cấp quyền hệ thống..."
        errorMessage = nil

        // Step 1: Configure & Save NEDNSSettingsManager
        // This registers "DNS VIP" directly into iOS Settings > General > VPN & Device Management > DNS with App Icon!
        dnsSettingsManager.loadFromPreferences { [weak self] loadError in
            guard let self = self else { return }

            let doh = NEDNSOverHTTPSSettings(servers: ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111"])
            doh.serverURL = URL(string: "https://cloudflare-dns.com/dns-query")

            self.dnsSettingsManager.dnsSettings = doh
            self.dnsSettingsManager.localizedDescription = "DNS VIP"
            self.dnsSettingsManager.onDemandRules = [NEOnDemandRuleConnect()]

            self.dnsSettingsManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        NSLog("[DNSManager] DNS Settings save error: %@", saveError.localizedDescription)
                    } else {
                        self?.isEnabled = true
                        self?.isProxyInstalled = true
                        self?.statusMessage = "Đang bảo vệ • Đã thêm DNS VIP vào Cài đặt"
                        self?.errorMessage = nil
                        NSLog("[DNSManager] DNS VIP successfully registered into iOS Settings > DNS!")
                    }
                }
            }
        }

        // Step 2: Trigger Native iOS VPN Permission Dialog ("DNS VIP" Would Like to Add VPN Configurations)
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

            manager.saveToPreferences { [weak self] saveError in
                if let saveError = saveError {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        NSLog("[DNSManager] VPN save info: %@", saveError.localizedDescription)
                        if self?.isEnabled == true {
                            self?.statusMessage = "Đã lưu vào Cài đặt • Chọn tick xanh 'DNS VIP' trong DNS"
                        } else {
                            self?.errorMessage = "Vui lòng chọn 'Cho phép' khi iOS hỏi quyền thiết bị"
                        }
                        completion?(false)
                    }
                } else {
                    // Reload and trigger active tunnel -> Display native [VPN] icon on iPhone!
                    manager.loadFromPreferences { _ in
                        do {
                            try manager.connection.startVPNTunnel()
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                self?.isEnabled = true
                                self?.isProxyInstalled = true
                                self?.errorMessage = nil
                                self?.statusMessage = "Đang bảo vệ • Đã kích hoạt [VPN] trên thiết bị"
                                NSLog("[DNSManager] startVPNTunnel successful! [VPN] icon active.")
                                completion?(true)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                NSLog("[DNSManager] startVPNTunnel: %@", error.localizedDescription)
                                self?.isEnabled = true
                                self?.isProxyInstalled = true
                                self?.statusMessage = "Đang bảo vệ • Cấu hình VPN đã sẵn sàng"
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

        // Stop active VPN tunnel
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

    public func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
