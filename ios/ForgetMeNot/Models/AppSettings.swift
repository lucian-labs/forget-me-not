import Foundation

struct AppSettings: Codable, Equatable {
    var soundEnabled: Bool = true
    var soundSeed: String = "forgetmenot"
    var soundPreset: Int = 0
    var soundBpm: Int = 160
    var soundVolume: Double = 0.4
    var soundMode: Int = 1
    var appName: String = ""
    var domains: [String] = ["home", "work", "health", "errands"]
    var themePreset: String = "midnight"
    var customColors: [String: String] = [:]
    var customBorderRadius: Double?
    var customFontSize: Double?
    var customHeaderFont: String?
    var customBodyFont: String?
    var syncEndpoint: String = ""
    var syncApiKey: String = ""
    var syncEnabled: Bool = false
}
