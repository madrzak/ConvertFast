import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuManager: MenuManager!
    private var conversionManager: ConversionManager!
    private var folderMonitor: FolderMonitor?
    private var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ConvertFastEnabled")
            menuManager.updateEnabledState(isEnabled)
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hide dock icon - set this as early as possible
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize ConversionManager
        conversionManager = ConversionManager()
                
        // Create a status item with fixed length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Configure the status item button
        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuIconV2") {
                icon.isTemplate = true // Enables dark/light mode adaptation
                button.image = icon
            } else {
                button.title = "⚡"
            }
            button.toolTip = "ConvertFast"
        }
        
        // Initialize MenuManager
        menuManager = MenuManager(statusItem: statusItem, isEnabled: isEnabled, conversionManager: conversionManager, appDelegate: self)
        statusItem.menu = menuManager.createMenu()
        
        // Check dependencies
        DependencyManager.shared.checkDependencies()
        
        // Restore previous state
        isEnabled = UserDefaults.standard.bool(forKey: "ConvertFastEnabled")
        
        // Restore previous watch folder if exists, otherwise use Desktop
        if let watchFolderPath = UserDefaults.standard.string(forKey: "WatchFolderPath") {
            let folderURL = URL(fileURLWithPath: watchFolderPath)
            setupFolderMonitoring(for: folderURL)
        }
        
        // Observe folder access changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFolderAccessGranted(_:)),
            name: .folderAccessGranted,
            object: nil
        )
        
        // Observe conversion progress updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConversionProgressUpdated(_:)),
            name: .conversionProgressUpdated,
            object: nil
        )
    }
    
    @objc private func handleConversionProgressUpdated(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let progress = userInfo["progress"] as? Double,
           let message = userInfo["message"] as? String {
            menuManager.updateProgress(progress, message: message)
        }
    }
    
    @objc func toggleAutoConvert() {
        isEnabled.toggle()
        if isEnabled {
            folderMonitor?.startMonitoring()
        } else {
            folderMonitor?.stopMonitoring()
        }
    }
    
    @objc func selectWatchFolder() {
        // Get the default URL (Desktop) if no folder is currently selected
        let defaultURL = UserDefaults.standard.string(forKey: "WatchFolderPath").map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = false
        panel.message = "Select a folder for ConvertFast to watch"
        panel.prompt = "Watch Folder"
        panel.directoryURL = defaultURL
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.urls.first {
                // Request permission for the selected folder
                PermissionManager.shared.requestFolderAccess(for: url) { granted in
                    if granted {
                        self?.setupFolderMonitoring(for: url)
                        UserDefaults.standard.set(url.path, forKey: "WatchFolderPath")
                    }
                }
            }
        }
    }
    
    @objc func forceConvert() {
        if let folderMonitor = folderMonitor {
            folderMonitor.forceConvert()
        } else {
            let alert = NSAlert()
            alert.messageText = "No Watch Folder Selected"
            alert.informativeText = "Please select a watch folder first."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    private func setupFolderMonitoring(for url: URL) {
        // For previously saved paths, only check if we can actually access the folder
        if UserDefaults.standard.string(forKey: "WatchFolderPath") == url.path {
            do {
                // Try to read the directory contents as a basic access test
                _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                // If we can read the directory, we have permission
                self.folderMonitor = FolderMonitor(url: url)
                if self.isEnabled {
                    self.folderMonitor?.startMonitoring()
                }
            } catch {
                // If we can't access the folder anymore, request permission again
                requestFolderPermission(for: url)
            }
        } else {
            // For new folders, always request permission
            requestFolderPermission(for: url)
        }
    }
    
    private func requestFolderPermission(for url: URL) {
        PermissionManager.shared.requestFolderAccess(for: url) { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                self.folderMonitor = FolderMonitor(url: url)
                if self.isEnabled {
                    self.folderMonitor?.startMonitoring()
                }
            } else {
                let alert = NSAlert()
                alert.messageText = "Permission Denied"
                alert.informativeText = "ConvertFast needs permission to access the selected folder. Please try again and grant access when prompted."
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    @objc private func handleFolderAccessGranted(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? URL {
            UserDefaults.standard.set(url.path, forKey: "WatchFolderPath")
            menuManager.updateMenu()
        }
    }
} 
