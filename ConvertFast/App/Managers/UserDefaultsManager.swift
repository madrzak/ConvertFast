import Foundation

/// Manages all UserDefaults operations in the app
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let isEnabled = "ConvertFastEnabled"
        static let watchFolderPath = "WatchFolderPath"
        static let conversionSettings = "ConversionSettings"
        static let folderBookmark = "FolderBookmark"
        static let ffmpegExists = "ffmpegExists"
        static let cwebpExists = "cwebpExists"
    }
    
    // MARK: - App State
    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }
    
    // MARK: - Watch Folder
    var watchFolderPath: String? {
        get { defaults.string(forKey: Keys.watchFolderPath) }
        set { defaults.set(newValue, forKey: Keys.watchFolderPath) }
    }
    
    var watchFolderURL: URL? {
        get {
            guard let path = watchFolderPath else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            watchFolderPath = newValue?.path
        }
    }
    
    // MARK: - Conversion Settings
    func saveConversionSettings(_ settings: [String: Any]) {
        defaults.set(settings, forKey: Keys.conversionSettings)
        defaults.synchronize()
    }
    
    func getConversionSettings() -> [String: Any]? {
        return defaults.dictionary(forKey: Keys.conversionSettings)
    }
    
    func saveEncodedConversionSettings(_ data: Data) {
        defaults.set(data, forKey: Keys.conversionSettings)
    }
    
    func getEncodedConversionSettings() -> Data? {
        return defaults.data(forKey: Keys.conversionSettings)
    }
    
    // MARK: - Folder Bookmarks
    func saveFolderBookmark(_ data: Data) {
        defaults.set(data, forKey: Keys.folderBookmark)
    }
    
    func getFolderBookmark() -> Data? {
        return defaults.data(forKey: Keys.folderBookmark)
    }
    
    // MARK: - Dependencies
    func setDependencyExists(_ exists: Bool, for dependency: String) {
        defaults.set(exists, forKey: "\(dependency)Exists")
    }
    
    var ffmpegExists: Bool {
        get { defaults.bool(forKey: Keys.ffmpegExists) }
        set { defaults.set(newValue, forKey: Keys.ffmpegExists) }
    }
    
    var cwebpExists: Bool {
        get { defaults.bool(forKey: Keys.cwebpExists) }
        set { defaults.set(newValue, forKey: Keys.cwebpExists) }
    }
} 

struct ConversionSettings: Codable {
    var soundEnabled: Bool = true
    var mp4Quality: Int = 23
    var mp4Preset: String = "fast"
    var webpQuality: Int = 85
    var transcriptionEnabled: Bool = false
}
