import Foundation
import AppKit

extension Notification.Name {
    static let folderAccessGranted = Notification.Name("folderAccessGranted")
}

class PermissionManager {
    static let shared = PermissionManager()
    private var currentBookmarkURL: URL?
    
    private init() {
        // Try to restore existing bookmark on launch
        if let bookmarkData = UserDefaults.standard.data(forKey: "FolderBookmark") {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if !isStale {
                    currentBookmarkURL = url
                    _ = url.startAccessingSecurityScopedResource()
                    print("✅ Successfully restored folder access on launch")
                }
            } catch {
                print("❌ Failed to restore bookmark: \(error.localizedDescription)")
            }
        }
    }
    
    func requestFolderAccess(for url: URL, completion: @escaping (Bool) -> Void) {
        // Create security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "FolderBookmark")
            print("✅ Folder access granted and bookmark saved")
            
            // Store the current URL and start accessing it
            self.currentBookmarkURL = url
            _ = url.startAccessingSecurityScopedResource()
            
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
    }
    
    func getFolderAccess(for url: URL) -> URL? {
        // First check if we have a valid current bookmark
        if let currentURL = currentBookmarkURL, currentURL.path == url.path {
            return currentURL
        }
        
        // Then try to resolve existing bookmark
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
                        currentBookmarkURL = bookmarkedURL
                        _ = bookmarkedURL.startAccessingSecurityScopedResource()
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
    
    deinit {
        // Stop accessing the resource when the manager is deallocated
        if let url = currentBookmarkURL {
            url.stopAccessingSecurityScopedResource()
        }
    }
} 