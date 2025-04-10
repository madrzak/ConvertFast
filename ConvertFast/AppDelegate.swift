import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var folderMonitor: FolderMonitor?
    private var hiddenWindow: NSWindow?
    private var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ConvertFastEnabled")
            updateMenuBar()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
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
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Check dependencies
        checkDependencies()
        
        // Restore previous state
        isEnabled = UserDefaults.standard.bool(forKey: "ConvertFastEnabled")
        
        // Restore previous watch folder if exists
        if let watchFolderPath = UserDefaults.standard.string(forKey: "WatchFolderPath") {
            setupFolderMonitoring(for: URL(fileURLWithPath: watchFolderPath))
        }
    }
    
    private func updateMenuBar() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Enable Auto-Convert", action: #selector(toggleAutoConvert), keyEquivalent: "")
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let selectFolderItem = NSMenuItem(title: "Select Watch Folder...", action: #selector(selectWatchFolder), keyEquivalent: "")
        menu.addItem(selectFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.setupFolderMonitoring(for: url)
                UserDefaults.standard.set(url.path, forKey: "WatchFolderPath")
            }
        }
    }
    
    private func setupFolderMonitoring(for url: URL) {
        folderMonitor = FolderMonitor(url: url)
        if isEnabled {
            folderMonitor?.startMonitoring()
        }
    }
    
    private func checkDependencies() {
        let dependencies = ["ffmpeg", "cwebp"]
        var missingDeps: [String] = []
        
        for dep in dependencies {
            if !checkIfCommandExists(dep) {
                missingDeps.append(dep)
            }
        }
        
        if !missingDeps.isEmpty {
            showDependencyAlert(missing: missingDeps)
        }
    }
    
    private func checkIfCommandExists(_ command: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
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
} 
