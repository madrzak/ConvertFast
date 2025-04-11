import Foundation
import AppKit

extension Notification.Name {
    static let folderAccessGranted = Notification.Name("folderAccessGranted")
}

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func requestFolderAccess(for url: URL, completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = false
        panel.message = "Select a folder for ConvertFast to monitor"
        panel.prompt = "Monitor Folder"
        
        // Enable security scope access
        panel.treatsFilePackagesAsDirectories = true
        panel.worksWhenModal = true
        
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                // Create security-scoped bookmark
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "FolderBookmark")
                    print("✅ Folder access granted and bookmark saved")
                    
                    // Post notification with the granted URL
                    NotificationCenter.default.post(
                        name: .folderAccessGranted,
                        object: nil,
                        userInfo: ["url": url]
                    )
                    
                    completion(true)
                } catch {
                    print("❌ Failed to create bookmark: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                print("❌ User cancelled folder selection")
                completion(false)
            }
        }
    }
    
    func getFolderAccess(for url: URL) -> URL? {
        // First try to resolve existing bookmark
        if let bookmarkData = UserDefaults.standard.data(forKey: "FolderBookmark") {
            do {
                var isStale = false
                let bookmarkedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Check if the bookmarked URL matches the requested URL
                if bookmarkedURL.path == url.path {
                    if !isStale {
                        return bookmarkedURL
                    }
                    print("⚠️ Bookmark is stale, need to request access again")
                }
            } catch {
                print("❌ Failed to resolve bookmark: \(error.localizedDescription)")
            }
        }
        
        // If we can't get access through bookmark, check if we have direct access
        if FileManager.default.isReadableFile(atPath: url.path) {
            return url
        }
        
        return nil
    }
} 