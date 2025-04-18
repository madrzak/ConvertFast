import Foundation

class FolderMonitor {
    private var folderURL: URL
    private var directoryFileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private let conversionManager: ConversionManager
    private var processedFiles: Set<String> = []
    private let fileCheckDelay: TimeInterval = 1.0 // 1 second delay to ensure file is fully written
    private var isAccessingSecurityScopedResource = false
    
    init(url: URL) {
        self.folderURL = url
        self.conversionManager = ConversionManager()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard source == nil else { return }
        
        print("🔍 Starting folder monitoring for: \(folderURL.path)")
        
        // Check if we have permission to access the folder
        guard let accessibleURL = PermissionManager.shared.getFolderAccess(for: folderURL) else {
            print("❌ No permission to access folder: \(folderURL.path)")
            return
        }
        
        // Start accessing the security-scoped resource
        isAccessingSecurityScopedResource = accessibleURL.startAccessingSecurityScopedResource()
        if isAccessingSecurityScopedResource {
            print("✅ Started accessing security-scoped resource")
        } else {
            print("⚠️ Failed to start accessing security-scoped resource")
        }
        
        directoryFileDescriptor = open(folderURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            print("❌ Failed to open directory for monitoring: \(folderURL.path)")
            return
        }
        
        // Use a more comprehensive event mask to catch all relevant file system events
        let eventMask: DispatchSource.FileSystemEvent = [.write, .extend, .attrib, .delete, .rename]
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: eventMask,
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
            
            // Stop accessing the security-scoped resource
            if self.isAccessingSecurityScopedResource {
                self.isAccessingSecurityScopedResource = false
                print("✅ Stopped accessing security-scoped resource")
            }
        }
        
        source?.resume()
        print("✅ Started monitoring folder: \(folderURL.path)")
        
        // Do an initial scan of the folder
        handleFolderChanges()
    }
    
    func stopMonitoring() {
        source?.cancel()
    }
    
    private func handleFolderChanges() {
        print("\n👀 Checking for new files in: \(folderURL.path)")
        
        // List all files in the directory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            print("📂 Found \(fileURLs.count) items in folder")
            
            var newFiles: [URL] = []
            for url in fileURLs {
                let filePath = url.path
                print("  📄 Checking file: \(url.lastPathComponent)")
                
                guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      !isDirectory else {
                    print("    ⏩ Skipping directory: \(url.lastPathComponent)")
                    continue
                }
                
                // Skip if we've already processed this file
                if processedFiles.contains(filePath) {
                    print("    ⏩ Already processed: \(url.lastPathComponent)")
                    continue
                }
                
                // Get file attributes
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
                let creationDate = resourceValues.creationDate
                let modificationDate = resourceValues.contentModificationDate
                let fileSize = resourceValues.fileSize ?? 0
                
                print("    📊 File info:")
                print("      - Creation date: \(creationDate?.description ?? "unknown")")
                print("      - Modification date: \(modificationDate?.description ?? "unknown")")
                print("      - Size: \(fileSize) bytes")
                
                // Process the file if it has content
                if fileSize > 0 {
                    print("    ✅ Processing file: \(url.lastPathComponent)")
                    newFiles.append(url)
                    processedFiles.insert(filePath)
                } else {
                    print("    ⚠️ File has no content: \(url.lastPathComponent)")
                }
            }
            
            if newFiles.count > 0 {
                print("✅ Auto-converting \(newFiles.count) new files.")
                conversionManager.startBatchConversion(files: newFiles)
            } else {
                print("ℹ️ No new files to convert.")
            }
        } catch {
            print("❌ Error listing directory contents: \(error.localizedDescription)")
        }
    }
    
    func forceConvert() {
        print("\n🔄 Force converting all files in: \(folderURL.path)")
        
        // Check if we have permission to access the folder
        guard let _ = PermissionManager.shared.getFolderAccess(for: folderURL) else {
            print("❌ No permission to access folder: \(folderURL.path)")
            return
        }
        
        // List all files in the directory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            print("📂 Found \(fileURLs.count) items in folder")
            
            var filesToConvert: [URL] = []
            for url in fileURLs {
                guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      !isDirectory else {
                    print("  ⏩ Skipping directory: \(url.lastPathComponent)")
                    continue
                }
                
                // Process all files in the folder
                print("  📄 Processing file: \(url.lastPathComponent)")
                filesToConvert.append(url)
                processedFiles.insert(url.path)
            }
            
            print("✅ Force conversion complete. Processing \(filesToConvert.count) files.")
            conversionManager.startBatchConversion(files: filesToConvert)
        } catch {
            print("❌ Error listing directory contents: \(error.localizedDescription)")
        }
    }
} 