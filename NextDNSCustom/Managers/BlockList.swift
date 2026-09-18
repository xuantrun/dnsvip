import Foundation

public struct BlockList {
    // Exact domain matches provided by User
    public static let defaultExactDomains: [String] = [
        "cdn-settings.appsflyersdk.com",
        "dl.aw.freefiremobile.com",
        "dl-us-production.freefiremobile.com",
        "dl.verus.freefiremobile.com",
        "version.ffmax.purplevioleto.com",
        "client.us.freefiremobile.com",
        "intlsdk.iegg.garena.com",
        "cloudctrl.gcloudsdk.com",
        "glcs.listdl.com",
        "dl.ctlin.freefiremobile.com",
        "dl.cvs.freefiremobile.com",
        "dl.gcp.freefiremobile.com",
        "conversions.appsflyer.com",
        "inapps.appsflyer.com",
        "dl-sg-production.freefiremobile.com",
        "gin.freefiremobile.com",
        "launches.appsflyer.com",
        "dl.castle.freefiremobile.com",
        "dl.dir.freefiremobile.com",
        "client.common.freefiremobile.com",
        "bdversion.ggbluefox.com",
        "freefiremobile-a.akamaihd.net",
        "csoversea.stronghold.freefiremobile.com",
        "dl.listdl.com",
        "ff.dr.grtc.garenanow.com",
        "dl.tata.freefiremobile.com",
        "ff.sdk.grtc.garenanow.com",
        "gcloudcs.com"
    ]

    // Wildcard suffix matches (*.domain.com)
    public static let defaultWildcards: [String] = [
        "dl.lost.freefiremobile.com",
        "akamai.net",
        "gopapi.io",
        "local.com",
        "ip.local.com",
        "freefiremax.freefiremobile.com",
        "rankguide.sea.freefiremobile.com",
        "rankgui.sea.freefiremobile.com",
        "rankred.sea.freefiremobile.com",
        "rankguide.oprn.freefiremobile.com",
        "hotro.ff.garena.com",
        "dl.cfn.freefiremobile.com",
        "dl.ar.freefiremobile.com",
        "a1818.dscw154.akamai.net",
        "dl.local.freefiremobile.com",
        "dl.iphack.freefiremobile.com",
        "gs.live.kg.garena.vn"
    ]

    private static let userDefaultsSuite = "group.com.nextdns.custom"
    private static let exactKey = "custom_exact_domains"
    private static let wildcardKey = "custom_wildcard_domains"

    public static func getExactDomains() -> [String] {
        let defaults = UserDefaults(suiteName: userDefaultsSuite) ?? UserDefaults.standard
        if let stored = defaults.stringArray(forKey: exactKey) {
            return stored
        }
        return defaultExactDomains
    }

    public static func getWildcards() -> [String] {
        let defaults = UserDefaults(suiteName: userDefaultsSuite) ?? UserDefaults.standard
        if let stored = defaults.stringArray(forKey: wildcardKey) {
            return stored
        }
        return defaultWildcards
    }

    public static func saveExactDomains(_ domains: [String]) {
        let defaults = UserDefaults(suiteName: userDefaultsSuite) ?? UserDefaults.standard
        defaults.set(domains, forKey: exactKey)
    }

    public static func saveWildcards(_ wildcards: [String]) {
        let defaults = UserDefaults(suiteName: userDefaultsSuite) ?? UserDefaults.standard
        defaults.set(wildcards, forKey: wildcardKey)
    }

    public static func resetToDefaults() {
        saveExactDomains(defaultExactDomains)
        saveWildcards(defaultWildcards)
    }

    public static func isBlocked(domain: String) -> Bool {
        var clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix(".") {
            clean.removeLast()
        }

        let exactSet = Set(getExactDomains().map { $0.lowercased() })
        if exactSet.contains(clean) {
            return true
        }

        let wildcards = getWildcards().map { $0.lowercased() }
        for wc in wildcards {
            let normalized = wc.hasPrefix("*.") ? String(wc.dropFirst(2)) : wc
            if clean == normalized || clean.hasSuffix("." + normalized) {
                return true
            }
        }

        return false
    }
}
