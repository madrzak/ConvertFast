import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var folderMonitor: FolderMonitor?
    private var hiddenWindow: NSWindow?
    private var conversionManager: ConversionManager!
    private var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ConvertFastEnabled")
            updateMenuBar()
        }
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
        
        // Create a hidden window to keep the app alive
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true
        window.alphaValue = 0
        window.orderOut(nil)
        hiddenWindow = window
        
        // Create a simple status item with text
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⚡"
        
        // Create menu
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Enable Auto-Convert", action: #selector(toggleAutoConvert), keyEquivalent: "")
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let selectFolderItem = NSMenuItem(title: "Select Watch Folder...", action: #selector(selectWatchFolder), keyEquivalent: "")
        menu.addItem(selectFolderItem)
        
        let forceConvertItem = NSMenuItem(title: "Force Convert Now", action: #selector(forceConvert), keyEquivalent: "r")
        menu.addItem(forceConvertItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versionItem = NSMenuItem(title: "ConvertFast v\(version)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)
        }
        
        // Add dependency versions
        let ffmpegVersion = getCommandVersion("ffmpeg")
        let ffmpegStatus = checkIfCommandExists("ffmpeg") ? "(ok)" : "❌"
        let ffmpegItem = NSMenuItem(title: "FFmpeg \(ffmpegStatus): \(ffmpegVersion)", action: nil, keyEquivalent: "")
        ffmpegItem.isEnabled = false
        menu.addItem(ffmpegItem)
        
        let cwebpVersion = getCommandVersion("cwebp")
        let cwebpStatus = checkIfCommandExists("cwebp") ? "(ok)" : "❌"
        let cwebpItem = NSMenuItem(title: "cwebp \(cwebpStatus): \(cwebpVersion)", action: nil, keyEquivalent: "")
        cwebpItem.isEnabled = false
        menu.addItem(cwebpItem)
        
        // Add watched folder info
        if let watchFolderPath = UserDefaults.standard.string(forKey: "WatchFolderPath") {
            let folderItem = NSMenuItem(title: "Watching: \(watchFolderPath)", action: nil, keyEquivalent: "")
            folderItem.isEnabled = false
            menu.addItem(folderItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
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
    }
    
    private func updateMenuBar() {
        let menu = NSMenu()
    
        
        let toggleItem = NSMenuItem(title: "Enable Auto ConvertFast", action: #selector(toggleAutoConvert), keyEquivalent: "")
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let selectFolderItem = NSMenuItem(title: "Select Watch Folder...", action: #selector(selectWatchFolder), keyEquivalent: "")
        menu.addItem(selectFolderItem)
        
        let forceConvertItem = NSMenuItem(title: "ConvertFast Now", action: #selector(forceConvert), keyEquivalent: "r")
        menu.addItem(forceConvertItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versionItem = NSMenuItem(title: "ConvertFast \(version)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)
        }
        
        // Add dependency versions
        let ffmpegVersion = getCommandVersion("ffmpeg")
        let ffmpegStatus = checkIfCommandExists("ffmpeg") ? "(ok)" : "❌"
        let ffmpegItem = NSMenuItem(title: "FFmpeg \(ffmpegStatus): \(ffmpegVersion)", action: nil, keyEquivalent: "")
        ffmpegItem.isEnabled = false
        menu.addItem(ffmpegItem)
        
        let cwebpVersion = getCommandVersion("cwebp")
        let cwebpStatus = checkIfCommandExists("cwebp") ? "(ok)" : "❌"
        let cwebpItem = NSMenuItem(title: "cwebp \(cwebpStatus): \(cwebpVersion)", action: nil, keyEquivalent: "")
        cwebpItem.isEnabled = false
        menu.addItem(cwebpItem)

        if let watchFolderPath = UserDefaults.standard.string(forKey: "WatchFolderPath") {
            let folderItem = NSMenuItem(title: "Watching: \(watchFolderPath)", action: nil, keyEquivalent: "")
            folderItem.isEnabled = false
            menu.addItem(folderItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func getCommandVersion(_ command: String) -> String {
        // Get the command path from ConversionManager
        let commandPath = conversionManager.getCommandPath(command)
        
        let process = Process()
        process.launchPath = "/bin/bash"
        
        // Different version command based on the tool
        let versionCommand = command == "ffmpeg" ? 
            "\"\(commandPath)\" -version | head -n 1 | awk '{print $3}'" :
            "\"\(commandPath)\" -version 2>&1 | head -n 1"
            
        process.arguments = ["-c", versionCommand]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return output
                }
            }
        } catch {
            print("Error getting version for \(command): \(error)")
        }
        
        return "Not found"
    }
    
    @objc private func toggleAutoConvert() {
        isEnabled.toggle()
        if isEnabled {
            folderMonitor?.startMonitoring()
        } else {
            folderMonitor?.stopMonitoring()
        }
    }
    
    @objc private func selectWatchFolder() {
        // Get the default URL (Desktop) if no folder is currently selected
        let defaultURL = UserDefaults.standard.string(forKey: "WatchFolderPath").map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = false
        panel.message = "Select a folder for ConvertFast to monitor"
        panel.prompt = "Monitor Folder"
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
    
    @objc private func forceConvert() {
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
            updateMenuBar()
        }
    }
} 
