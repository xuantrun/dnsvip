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
    @Published public var upstreamServer: String = "Cloudflare Anycast (1.1.1.1)"
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
    }

    private func handleVPNStatusChange() {
        guard let mgr = tunnelManager else { return }
        switch mgr.connection.status {
        case .connected:
            self.isEnabled = true
            self.isProxyInstalled = true
            self.statusMessage = "Đang bảo vệ • [VPN] đang chặn game & quảng cáo"
            self.errorMessage = nil
            QueryLogManager.shared.fetchLogsFromTunnel()
            NSLog("[DNSManager] VPN Status: CONNECTED -> Active [VPN] protection!")
        case .connecting:
            self.statusMessage = "Đang kết nối VPN..."
        case .disconnecting:
            self.statusMessage = "Đang ngắt kết nối VPN..."
        case .disconnected, .invalid:
            self.isEnabled = false
            self.statusMessage = "Chưa kích hoạt"
        case .reasserting:
            self.statusMessage = "Đang tái thiết lập VPN..."
        @unknown default:
            break
        }
    }

    public func loadStatus() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            DispatchQueue.main.async {
                if let mgr = managers?.first {
                    self?.tunnelManager = mgr
                    if mgr.connection.status == .connected {
                        self?.isEnabled = true
                        self?.isProxyInstalled = true
                        self?.statusMessage = "Đang bảo vệ • [VPN] đang chặn game & quảng cáo"
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

    // Auto-request VPN permission like NextDNS and start tunnel
    public func enableAllProtection(completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        statusMessage = "Đang khởi chạy bộ lọc VPN..."
        errorMessage = nil

        // Clean up any old DoH settings so it doesn't bypass our VPN tunnel
        dnsSettingsManager.loadFromPreferences { [weak self] _ in
            self?.dnsSettingsManager.removeFromPreferences { _ in }
        }

        // Configure & Trigger Native iOS VPN Tunnel
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
                guard let self = self else { return }
                if let saveError = saveError {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        NSLog("[DNSManager] VPN save error: %@", saveError.localizedDescription)
                        self.errorMessage = "Vui lòng chọn 'Cho phép' khi iOS hỏi quyền VPN"
                        completion?(false)
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
                                self.statusMessage = "Đang bảo vệ • Đã kích hoạt [VPN]"
                                NSLog("[DNSManager] startVPNTunnel successful! [VPN] icon active.")
                                QueryLogManager.shared.fetchLogsFromTunnel()
                                completion?(true)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                NSLog("[DNSManager] startVPNTunnel failed: %@", error.localizedDescription)
                                self.errorMessage = "Không thể bật VPN: \(error.localizedDescription)"
                                completion?(false)
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
    }

    public func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
