import Foundation
import Cocoa

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func requestFolderAccess(for url: URL, completion: @escaping (Bool) -> Void) {
        // Check if we already have access
        if hasFolderAccess(for: url) {
            completion(true)
            return
        }
        
        // Request access using NSOpenPanel
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.message = "ConvertFast needs access to this folder to monitor and convert files."
        panel.prompt = "Grant Access"
        
        panel.begin { response in
            if response == .OK, let selectedURL = panel.url {
                // User selected the folder, now request security-scoped access
                let shouldStopAccessing = selectedURL.startAccessingSecurityScopedResource()
                
                // Save the bookmark for future use
                do {
                    let bookmarkData = try selectedURL.bookmarkData(
                        options: .withSecurityScope,
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
        // Try to access the folder to check permissions
        let fileManager = FileManager.default
        return fileManager.isReadableFile(atPath: url.path)
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
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(newBookmarkData, forKey: "FolderBookmark")
            }
            
            return url
        } catch {
            print("❌ Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
} 