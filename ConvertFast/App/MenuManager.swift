import Cocoa

class MenuManager {
    private var statusItem: NSStatusItem
    private var progressIndicator: NSProgressIndicator?
    private var progressItem: NSMenuItem?
    private var isEnabled: Bool
    private var conversionManager: ConversionManager
    private var settingsWindowController: SettingsWindowController?
    
    init(statusItem: NSStatusItem, isEnabled: Bool, conversionManager: ConversionManager) {
        self.statusItem = statusItem
        self.isEnabled = isEnabled
        self.conversionManager = conversionManager
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Enable Auto-Convert", action: #selector(AppDelegate.toggleAutoConvert), keyEquivalent: "")
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let selectFolderItem = NSMenuItem(title: "Select Watch Folder...", action: #selector(AppDelegate.selectWatchFolder), keyEquivalent: "")
        menu.addItem(selectFolderItem)
        
        let forceConvertItem = NSMenuItem(title: "Force Convert Now", action: #selector(AppDelegate.forceConvert), keyEquivalent: "r")
        menu.addItem(forceConvertItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add progress indicator
        let progressView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 16))
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 200, height: 16))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .small
        progressIndicator.isBezeled = true
        progressIndicator.isHidden = true
        progressView.addSubview(progressIndicator)
        self.progressIndicator = progressIndicator
        
        let progressItem = NSMenuItem(title: getRandomIdleMessage(), action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        menu.addItem(progressItem)
        self.progressItem = progressItem
        
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
        
        return menu
    }
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            settingsWindowController = SettingsWindowController(window: window)
        }
        
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateProgress(_ progress: Double, message: String) {
        progressIndicator?.doubleValue = progress
        progressItem?.title = message
    }
    
    private func getRandomIdleMessage() -> String {
        let messages = [
            "Ready to convert...",
            "Waiting for files...",
            "Idle...",
            "Drop files here..."
        ]
        return messages.randomElement() ?? "Ready"
    }
    
    private func getCommandVersion(_ command: String) -> String {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let versionProcess = Process()
                    versionProcess.launchPath = path
                    versionProcess.arguments = ["-version"]
                    
                    let versionPipe = Pipe()
                    versionProcess.standardOutput = versionPipe
                    
                    try versionProcess.run()
                    versionProcess.waitUntilExit()
                    
                    let versionData = versionPipe.fileHandleForReading.readDataToEndOfFile()
                    if let versionOutput = String(data: versionData, encoding: .utf8) {
                        let firstLine = versionOutput.components(separatedBy: .newlines).first ?? ""
                        return firstLine
                    }
                }
            }
        } catch {
            print("Error getting version for \(command): \(error)")
        }
        
        return "Not found"
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
} 