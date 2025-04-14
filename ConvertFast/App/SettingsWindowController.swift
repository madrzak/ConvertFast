import Cocoa

class SettingsWindowController: NSWindowController {
    private var soundToggle: NSButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var qualityDescription: NSTextField!
    private var presetPopup: NSPopUpButton!
    private var jpegQualitySlider: NSSlider!
    private var jpegQualityLabel: NSTextField!
    private var settings: [String: Any] = [:]
    
    // CRF quality presets
    private let qualityPresets: [(value: Int, description: String)] = [
        (18, "Visually Lossless - Highest Quality"),
        (23, "High Quality - Default"),
        (28, "Good Quality - Smaller Size"),
        (35, "Medium Quality - Small Size"),
        (51, "Lowest Quality - Smallest Size")
    ]
    
    override init(window: NSWindow?) {
        super.init(window: window)
        print("Window controller initialized with window")
    }
    
    convenience init() {
        print("Creating new settings window")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ConvertFast Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        self.setupUI()
        self.updateUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("Window did load")
        
        // Load saved settings
        settings = UserDefaults.standard.dictionary(forKey: "ConversionSettings") ?? [
            "soundEnabled": true,
            "mp4Quality": 23,
            "mp4Preset": "fast"
        ]
        
        setupUI()
        updateUI()
        
        print("Window setup complete")
    }
    
    private func setupUI() {
        print("Setting up UI")
        print("window is nil? \(window == nil)")
        print("contentView is nil? \(window?.contentView == nil)")

        guard let contentView = window?.contentView else { 
            print("Content view is nil, cannot setup UI")
            return 
        }
        
        // Set background color to make sure content view is visible
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Sound toggle
        let soundLabel = NSTextField(labelWithString: "Play sound when conversion completes")
        soundLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(soundLabel)
        
        soundToggle = NSButton(checkboxWithTitle: "", target: self, action: #selector(soundToggleChanged))
        soundToggle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(soundToggle)
        
        // MP4 Settings group
        let mp4Group = NSBox()
        mp4Group.title = "MP4 Conversion Settings"
        mp4Group.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mp4Group)
        
        // Quality slider
        let qualityTitle = NSTextField(labelWithString: "Quality (CRF)")
        qualityTitle.translatesAutoresizingMaskIntoConstraints = false
        mp4Group.addSubview(qualityTitle)
        
        qualitySlider = NSSlider(target: self, action: #selector(qualityChanged))
        qualitySlider.translatesAutoresizingMaskIntoConstraints = false
        qualitySlider.minValue = 0
        qualitySlider.maxValue = 51
        qualitySlider.doubleValue = 23
        qualitySlider.isContinuous = true
        qualitySlider.toolTip = "Lower values mean higher quality but larger file size. Higher values mean lower quality but smaller file size."
        mp4Group.addSubview(qualitySlider)
        
        qualityLabel = NSTextField(labelWithString: "23")
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        mp4Group.addSubview(qualityLabel)
        
        // Quality description
        qualityDescription = NSTextField(labelWithString: "High Quality - Default")
        qualityDescription.translatesAutoresizingMaskIntoConstraints = false
        qualityDescription.textColor = .secondaryLabelColor
        qualityDescription.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        mp4Group.addSubview(qualityDescription)
        
        // Preset popup
        let presetLabel = NSTextField(labelWithString: "Encoding Preset")
        presetLabel.translatesAutoresizingMaskIntoConstraints = false
        mp4Group.addSubview(presetLabel)
        
        presetPopup = NSPopUpButton()
        presetPopup.addItems(withTitles: ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"])
        presetPopup.translatesAutoresizingMaskIntoConstraints = false
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        presetPopup.toolTip = "Faster presets encode quicker but produce larger files. Slower presets take longer but produce smaller files."
        mp4Group.addSubview(presetPopup)
        
        // Image Settings group
        let imageGroup = NSBox()
        imageGroup.title = "Image Conversion Settings"
        imageGroup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageGroup)
        
        // JPEG Quality slider
        let jpegQualityTitle = NSTextField(labelWithString: "JPEG Quality")
        jpegQualityTitle.translatesAutoresizingMaskIntoConstraints = false
        imageGroup.addSubview(jpegQualityTitle)
        
        jpegQualitySlider = NSSlider(target: self, action: #selector(jpegQualityChanged))
        jpegQualitySlider.translatesAutoresizingMaskIntoConstraints = false
        jpegQualitySlider.minValue = 0
        jpegQualitySlider.maxValue = 100
        jpegQualitySlider.doubleValue = 85
        jpegQualitySlider.isContinuous = true
        jpegQualitySlider.toolTip = "Higher values mean better quality but larger file size."
        imageGroup.addSubview(jpegQualitySlider)
        
        jpegQualityLabel = NSTextField(labelWithString: "85")
        jpegQualityLabel.translatesAutoresizingMaskIntoConstraints = false
        imageGroup.addSubview(jpegQualityLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            soundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            soundLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            
            soundToggle.leadingAnchor.constraint(equalTo: soundLabel.trailingAnchor, constant: 8),
            soundToggle.centerYAnchor.constraint(equalTo: soundLabel.centerYAnchor),
            
            mp4Group.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mp4Group.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mp4Group.topAnchor.constraint(equalTo: soundLabel.bottomAnchor, constant: 20),
            
            qualityTitle.leadingAnchor.constraint(equalTo: mp4Group.leadingAnchor, constant: 10),
            qualityTitle.topAnchor.constraint(equalTo: mp4Group.topAnchor, constant: 30),
            
            qualitySlider.leadingAnchor.constraint(equalTo: qualityTitle.trailingAnchor, constant: 20),
            qualitySlider.centerYAnchor.constraint(equalTo: qualityTitle.centerYAnchor),
            qualitySlider.widthAnchor.constraint(equalToConstant: 200),
            
            qualityLabel.leadingAnchor.constraint(equalTo: qualitySlider.trailingAnchor, constant: 8),
            qualityLabel.centerYAnchor.constraint(equalTo: qualityTitle.centerYAnchor),
            
            qualityDescription.leadingAnchor.constraint(equalTo: qualityTitle.leadingAnchor),
            qualityDescription.topAnchor.constraint(equalTo: qualityTitle.bottomAnchor, constant: 4),
            
            presetLabel.leadingAnchor.constraint(equalTo: mp4Group.leadingAnchor, constant: 10),
            presetLabel.topAnchor.constraint(equalTo: qualityDescription.bottomAnchor, constant: 20),
            
            presetPopup.leadingAnchor.constraint(equalTo: presetLabel.trailingAnchor, constant: 20),
            presetPopup.centerYAnchor.constraint(equalTo: presetLabel.centerYAnchor),
            presetPopup.widthAnchor.constraint(equalToConstant: 150),
            
            // Image settings constraints
            imageGroup.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageGroup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageGroup.topAnchor.constraint(equalTo: mp4Group.bottomAnchor, constant: 20),
            
            jpegQualityTitle.leadingAnchor.constraint(equalTo: imageGroup.leadingAnchor, constant: 10),
            jpegQualityTitle.topAnchor.constraint(equalTo: imageGroup.topAnchor, constant: 30),
            
            jpegQualitySlider.leadingAnchor.constraint(equalTo: jpegQualityTitle.trailingAnchor, constant: 20),
            jpegQualitySlider.centerYAnchor.constraint(equalTo: jpegQualityTitle.centerYAnchor),
            jpegQualitySlider.widthAnchor.constraint(equalToConstant: 200),
            
            jpegQualityLabel.leadingAnchor.constraint(equalTo: jpegQualitySlider.trailingAnchor, constant: 8),
            jpegQualityLabel.centerYAnchor.constraint(equalTo: jpegQualityTitle.centerYAnchor)
        ])
        
        print("UI setup complete")
    }
    
    private func updateUI() {
        soundToggle.state = (settings["soundEnabled"] as? Bool ?? true) ? .on : .off
        qualitySlider.doubleValue = settings["mp4Quality"] as? Double ?? 23
        updateQualityDescription(Int(qualitySlider.doubleValue))
        if let preset = settings["mp4Preset"] as? String {
            presetPopup.selectItem(withTitle: preset)
        }
    }
    
    private func updateQualityDescription(_ value: Int) {
        qualityLabel.stringValue = String(value)
        
        // Find the closest preset
        let closestPreset = qualityPresets.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? qualityPresets[1]
        qualityDescription.stringValue = closestPreset.description
    }
    
    @objc private func soundToggleChanged() {
        settings["soundEnabled"] = soundToggle.state == .on
        saveSettings()
    }
    
    @objc private func qualityChanged() {
        let quality = Int(qualitySlider.doubleValue)
        updateQualityDescription(quality)
        settings["mp4Quality"] = quality
        saveSettings()
    }
    
    @objc private func presetChanged() {
        settings["mp4Preset"] = presetPopup.selectedItem?.title
        saveSettings()
    }
    
    @objc private func jpegQualityChanged() {
        settings["jpegQuality"] = Int(jpegQualitySlider.doubleValue)
        jpegQualityLabel.stringValue = String(Int(jpegQualitySlider.doubleValue))
        saveSettings()
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(settings, forKey: "ConversionSettings")
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
} 
