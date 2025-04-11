import Foundation
import Cocoa

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func requestFolderAccess(for url: URL, completion: @escaping (Bool) -> Void) {
        // First check if we have a valid bookmark
        if let bookmarkedURL = getBookmarkedFolderURL(), bookmarkedURL.path == url.path {
            // We have a valid bookmark for this URL
            let canAccess = bookmarkedURL.startAccessingSecurityScopedResource()
            if canAccess {
                bookmarkedURL.stopAccessingSecurityScopedResource()
                completion(true)
                return
            }
        }
        
        // Request access using NSOpenPanel
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.message = "ConvertFast needs access to this folder to monitor and convert files."
        panel.prompt = "Grant Access"
        
        // Make panel appear on top of other windows
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
        
        panel.begin { response in
            if response == .OK, let selectedURL = panel.url {
                // User selected the folder, now request security-scoped access
                let shouldStopAccessing = selectedURL.startAccessingSecurityScopedResource()
                
                // Save the bookmark for future use
                do {
                    let bookmarkData = try selectedURL.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "FolderBookmark")
                    print("✅ Folder access granted and bookmark saved")
                    completion(true)
                } catch {
                    print("❌ Failed to create bookmark: \(error.localizedDescription)")
                    completion(false)
                }
                
                if shouldStopAccessing {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            } else {
                print("❌ User denied folder access")
                completion(false)
            }
        }
    }
    
    func hasFolderAccess(for url: URL) -> Bool {
        // First check if we have a valid bookmark for this URL
        if let bookmarkedURL = getBookmarkedFolderURL(), bookmarkedURL.path == url.path {
            let canAccess = bookmarkedURL.startAccessingSecurityScopedResource()
            if canAccess {
                bookmarkedURL.stopAccessingSecurityScopedResource()
                return true
            }
        }
        
        // If no bookmark or can't access, try direct access
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    func getBookmarkedFolderURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "FolderBookmark") else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // If the bookmark is stale, update it
            if isStale {
                let newBookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(newBookmarkData, forKey: "FolderBookmark")
            }
            
            return url
        } catch {
            print("❌ Failed to resolve bookmark: \(error.localizedDescription)")
            // Clean up invalid bookmark
            UserDefaults.standard.removeObject(forKey: "FolderBookmark")
            return nil
        }
    }
} 