import Cocoa

class MenuManager {
    private var statusItem: NSStatusItem
    private var progressIndicator: NSProgressIndicator?
    private var progressItem: NSMenuItem?
    private var isEnabled: Bool
    private var conversionManager: ConversionManager
    private var settingsWindowController: SettingsWindowController?
    private var appDelegate: AppDelegate?
    
    init(statusItem: NSStatusItem, isEnabled: Bool, conversionManager: ConversionManager, appDelegate: AppDelegate) {
        self.statusItem = statusItem
        self.isEnabled = isEnabled
        self.conversionManager = conversionManager
        self.appDelegate = appDelegate
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Enable Auto-Convert", action: #selector(toggleAutoConvert), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let selectFolderItem = NSMenuItem(title: "Select Watch Folder...", action: #selector(selectWatchFolder), keyEquivalent: "")
        selectFolderItem.target = self
        menu.addItem(selectFolderItem)
        
        let forceConvertItem = NSMenuItem(title: "Convert Now", action: #selector(forceConvert), keyEquivalent: "r")
        forceConvertItem.target = self
        menu.addItem(forceConvertItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
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
        
        let progressItem = NSMenuItem(title: MessageUtils.shared.getRandomIdleMessage(), action: nil, keyEquivalent: "")
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
        let ffmpegVersion = DependencyManager.shared.getCommandVersion("ffmpeg")
        let ffmpegStatus = UserDefaultsManager.shared.ffmpegExists ? "(ok)" : "❌"
        let ffmpegItem = NSMenuItem(title: "FFmpeg \(ffmpegStatus): \(ffmpegVersion)", action: nil, keyEquivalent: "")
        ffmpegItem.isEnabled = false
        menu.addItem(ffmpegItem)
        
        let cwebpVersion = DependencyManager.shared.getCommandVersion("cwebp")
        let cwebpStatus = UserDefaultsManager.shared.cwebpExists ? "(ok)" : "❌"
        let cwebpItem = NSMenuItem(title: "cwebp \(cwebpStatus): \(cwebpVersion)", action: nil, keyEquivalent: "")
        cwebpItem.isEnabled = false
        menu.addItem(cwebpItem)
        
        let magickVersion = DependencyManager.shared.getCommandVersion("magick")
        let magickStatus = UserDefaultsManager.shared.magickExists ? "(ok)" : "❌"
        let magickItem = NSMenuItem(title: "ImageMagick \(magickStatus): \(magickVersion)", action: nil, keyEquivalent: "")
        magickItem.isEnabled = false
        menu.addItem(magickItem)
        
        // Add watched folder info
        if let watchFolderPath = UserDefaultsManager.shared.watchFolderPath {
            let folderItem = NSMenuItem(title: "Watching: \(watchFolderPath)", action: nil, keyEquivalent: "")
            folderItem.isEnabled = false
            menu.addItem(folderItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    func updateEnabledState(_ enabled: Bool) {
        isEnabled = enabled
        DispatchQueue.main.async {
            self.updateMenu()
        }
    }
    
    func updateMenu() {
        DispatchQueue.main.async {
            let newMenu = self.createMenu()
            self.statusItem.menu = newMenu
        }
    }
    
    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            
            // Ensure window is loaded
            settingsWindowController?.loadWindow()
        }
        
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func toggleAutoConvert() {
        appDelegate?.toggleAutoConvert()
    }
    
    @objc func selectWatchFolder() {
        appDelegate?.selectWatchFolder()
    }
    
    @objc func forceConvert() {
        appDelegate?.forceConvert()
    }
    
    func updateProgress(_ progress: Double, message: String) {
        DispatchQueue.main.async {
            self.progressIndicator?.doubleValue = progress
            self.progressItem?.title = message
            self.updateMenu()
        }
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
    
} 
