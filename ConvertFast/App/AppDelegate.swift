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
    
    private func getRandomIdleMessage() -> String {
        let idleMessages = [
            "Watching folder for signs of life...",
            "Ready to convert your media...",
            "Idle mode: coffee break",
            "Monitoring for new files...",
            "Standing by for conversion duty..."
        ]
        return idleMessages.randomElement() ?? "Watching folder for signs of life..."
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hide dock icon - set this as early as possible
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize ConversionManager
        conversionManager = ConversionManager()
        
        // Test command execution
        conversionManager.testCommands()
                
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
        checkDependencies()
        
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
    
    private func checkDependencies() {
        let dependencies = ["ffmpeg", "cwebp"]
        var missingDeps: [String] = []
        
        for dep in dependencies {
            print("Checking for dependency: \(dep)")
            if !checkIfCommandExists(dep) {
                print("❌ \(dep) not found")
                missingDeps.append(dep)
            } else {
                print("✅ \(dep) found")
            }
        }
        
        if !missingDeps.isEmpty {
            showDependencyAlert(missing: missingDeps)
        }
    }
    
    private func checkIfCommandExists(_ command: String) -> Bool {
        print("🔍 Checking for command: \(command)")
        
        // Check in /opt/homebrew/bin
        let homebrewPath = "/opt/homebrew/bin/\(command)"
        print("  Checking Homebrew path: \(homebrewPath)")
        
        let process = Process()
        process.launchPath = "/usr/bin/readlink"
        process.arguments = ["-f", homebrewPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let resolvedPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    print("  ✅ Command found at: \(resolvedPath)")
                    return true
                }
            }
            
            print("  ❌ Command not found: \(command)")
            return false
        } catch {
            print("  ❌ Error checking for command \(command): \(error)")
            return false
        }
    }
    
    private func showDependencyAlert(missing: [String]) {
        let alert = NSAlert()
        alert.messageText = "Missing Dependencies"
        alert.informativeText = "The following required dependencies are missing:\n\(missing.joined(separator: ", "))\n\nWould you like to install them using Homebrew?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            installDependencies(missing)
        }
    }
    
    private func installDependencies(_ missing: [String]) {
        let script = """
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install \(missing.joined(separator: " "))
        """
        
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", script]
        
        do {
            try process.run()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Installation Failed"
            alert.informativeText = "Failed to install dependencies. Please install Homebrew and run: brew install \(missing.joined(separator: " "))"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    @objc private func handleFolderAccessGranted(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? URL {
            UserDefaults.standard.set(url.path, forKey: "WatchFolderPath")
            menuManager.updateMenu()
        }
    }
} 
