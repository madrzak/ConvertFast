import Foundation

class FolderMonitor {
    private var folderURL: URL
    private var directoryFileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private let conversionManager: ConversionManager
    
    init(url: URL) {
        self.folderURL = url
        self.conversionManager = ConversionManager()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard source == nil else { return }
        
        // Check if we have permission to access the folder
        if !PermissionManager.shared.hasFolderAccess(for: folderURL) {
            print("❌ No permission to access folder: \(folderURL.path)")
            return
        }
        
        // Start accessing the security-scoped resource if we have a bookmark
        if let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            let shouldStopAccessing = bookmarkedURL.startAccessingSecurityScopedResource()
            if shouldStopAccessing {
                // We'll stop accessing when we're done
                print("✅ Started accessing security-scoped resource")
            }
        }
        
        directoryFileDescriptor = open(folderURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            print("❌ Failed to open directory for monitoring: \(folderURL.path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        source?.setEventHandler { [weak self] in
            self?.handleFolderChanges()
        }
        
        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.directoryFileDescriptor)
            self.directoryFileDescriptor = -1
            self.source = nil
        }
        
        source?.resume()
        print("✅ Started monitoring folder: \(folderURL.path)")
    }
    
    func stopMonitoring() {
        source?.cancel()
        
        // Stop accessing the security-scoped resource
        if let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            bookmarkedURL.stopAccessingSecurityScopedResource()
            print("✅ Stopped accessing security-scoped resource")
        }
    }
    
    func forceConvert() {
        print("🔄 Force converting all files in: \(folderURL.path)")
        
        // Check if we have permission to access the folder
        if !PermissionManager.shared.hasFolderAccess(for: folderURL) {
            print("❌ No permission to access folder: \(folderURL.path)")
            return
        }
        
        // Start accessing the security-scoped resource if we have a bookmark
        var shouldStopAccessing = false
        if let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            shouldStopAccessing = bookmarkedURL.startAccessingSecurityScopedResource()
            if shouldStopAccessing {
                print("✅ Started accessing security-scoped resource")
            }
        }
        
        // List all files in the directory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var fileCount = 0
            for url in fileURLs {
                guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      !isDirectory else { continue }
                
                // Process all files in the folder
                print("  📄 Found file: \(url.lastPathComponent)")
                conversionManager.processFile(at: url)
                fileCount += 1
            }
            
            print("✅ Force conversion complete. Processed \(fileCount) files.")
        } catch {
            print("❌ Error listing directory contents: \(error.localizedDescription)")
        }
        
        // Stop accessing the security-scoped resource
        if shouldStopAccessing, let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            bookmarkedURL.stopAccessingSecurityScopedResource()
            print("✅ Stopped accessing security-scoped resource")
        }
    }
    
    private func handleFolderChanges() {
        print("👀 Checking for new files in: \(folderURL.path)")
        
        // Start accessing the security-scoped resource if we have a bookmark
        var shouldStopAccessing = false
        if let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            shouldStopAccessing = bookmarkedURL.startAccessingSecurityScopedResource()
            if shouldStopAccessing {
                print("✅ Started accessing security-scoped resource")
            }
        }
        
        // List all files in the directory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var newFileCount = 0
            for url in fileURLs {
                guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      !isDirectory else { continue }
                
                // Check if this is a new file (created in the last 5 seconds)
                if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   Date().timeIntervalSince(creationDate) < 5 {
                    print("  📄 New file detected: \(url.lastPathComponent)")
                    conversionManager.processFile(at: url)
                    newFileCount += 1
                }
            }
            
            if newFileCount > 0 {
                print("✅ Auto-converted \(newFileCount) new files.")
            }
        } catch {
            print("❌ Error listing directory contents: \(error.localizedDescription)")
        }
        
        // Stop accessing the security-scoped resource
        if shouldStopAccessing, let bookmarkedURL = PermissionManager.shared.getBookmarkedFolderURL() {
            bookmarkedURL.stopAccessingSecurityScopedResource()
            print("✅ Stopped accessing security-scoped resource")
        }
    }
} 