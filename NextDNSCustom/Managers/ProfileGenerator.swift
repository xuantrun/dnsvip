import Foundation
import UIKit

public struct ProfileGenerator {
    public static func generateMobileConfig(profileID: String, deviceName: String) -> Data? {
        let cleanID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevice = deviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "iPhone"
        
        let dohURL = cleanID.isEmpty 
            ? "https://dns.nextdns.io" 
            : "https://dns.nextdns.io/\(cleanID)/\(cleanDevice)"
        
        let displayName = cleanID.isEmpty 
            ? "NextDNS VIP (Chặn FreeFire)" 
            : "NextDNS (\(cleanID))"

        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>DNSSettings</key>
                    <dict>
                        <key>DNSProtocol</key>
                        <string>HTTPS</string>
                        <key>ServerAddresses</key>
                        <array>
                            <string>45.90.28.0</string>
                            <string>45.90.30.0</string>
                            <string>2a07:a8c0::</string>
                            <string>2a07:a8c1::</string>
                        </array>
                        <key>ServerURL</key>
                        <string>\(dohURL)</string>
                    </dict>
                    <key>PayloadDescription</key>
                    <string>Cấu hình DNS bảo mật và lọc tên miền NextDNS VIP</string>
                    <key>PayloadDisplayName</key>
                    <string>\(displayName)</string>
                    <key>PayloadIdentifier</key>
                    <string>com.nextdns.custom.dns.\(uuid1)</string>
                    <key>PayloadType</key>
                    <string>com.apple.dnsSettings.managed</string>
                    <key>PayloadUUID</key>
                    <string>\(uuid1)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>Cấu hình DNS bảo mật NextDNS</string>
            <key>PayloadDisplayName</key>
            <string>\(displayName)</string>
            <key>PayloadIdentifier</key>
            <string>com.nextdns.custom.profile.\(uuid2)</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(uuid2)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        return xml.data(using: .utf8)
    }

    public static func saveAndShareMobileConfig(profileID: String, deviceName: String, from viewController: UIViewController? = nil) {
        guard let data = generateMobileConfig(profileID: profileID, deviceName: deviceName) else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("NextDNS_Custom.mobileconfig")
        
        try? data.write(to: fileURL)
        
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }
}
