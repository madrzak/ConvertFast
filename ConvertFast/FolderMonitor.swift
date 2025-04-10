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
        
        directoryFileDescriptor = open(folderURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }
        
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
    }
    
    func stopMonitoring() {
        source?.cancel()
    }
    
    private func handleFolderChanges() {
        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  !isDirectory else { continue }
            
            // Check if this is a new file (created in the last 5 seconds)
            if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               Date().timeIntervalSince(creationDate) < 5 {
                conversionManager.processFile(at: url)
            }
        }
    }
} 