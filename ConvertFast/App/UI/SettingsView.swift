import SwiftUI

struct SettingsView: View {
    @AppStorage("ConversionSettings") private var settings: Data = try! JSONEncoder().encode(ConversionSettings())
    @State private var currentSettings: ConversionSettings
    
    init() {
        let decoder = JSONDecoder()
        _currentSettings = State(initialValue: (try? decoder.decode(ConversionSettings.self, from: UserDefaultsManager.shared.getEncodedConversionSettings() ?? Data())) ?? ConversionSettings())
    }
    
    private let mp4QualityPresets: [(value: Int, description: String)] = [
        (18, "Visually Lossless - Highest Quality"),
        (23, "High Quality - Default"),
        (28, "Good Quality - Smaller Size"),
        (35, "Medium Quality - Small Size"),
        (51, "Lowest Quality - Smallest Size")
    ]
    
    private let webpQualityPresets: [(value: Int, description: String)] = [
        (100, "Lossless - Maximum Quality"),
        (90, "Very High Quality - Minimal Loss"),
        (85, "High Quality - Default"),
        (75, "Good Quality - Better Compression"),
        (60, "Medium Quality - Small Size"),
        (45, "Low Quality - Tiny Size")
    ]
    
    private let encodingPresets = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"]
    
    var body: some View {
        Form {
            Section {
                Toggle("Play sound when conversion completes", isOn: soundEnabledBinding)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("MP4 Conversion Settings").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        HStack {
                            Text("Quality (CRF)")
                            Spacer()
                            Text("\(currentSettings.mp4Quality)")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(currentSettings.mp4Quality) },
                                set: { currentSettings.mp4Quality = Int(round($0)) }
                            ),
                            in: 0...51,
                            step: 1
                        ) { isEditing in
                            if !isEditing {
                                print("MP4 quality changed to: \(currentSettings.mp4Quality)")
                                saveSettings()
                            }
                        }
                        
                        // Force description to update with current value
                        Text("\(mp4QualityDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Picker("Encoding Preset", selection: mp4PresetBinding) {
                        ForEach(encodingPresets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Image Conversion Settings").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        HStack {
                            Text("WebP Quality")
                            Spacer()
                            Text("\(currentSettings.webpQuality)")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(currentSettings.webpQuality) },
                                set: { currentSettings.webpQuality = Int(round($0)) }
                            ),
                            in: 0...100,
                            step: 1
                        ) { isEditing in
                            if !isEditing {
                                print("WebP quality changed to: \(currentSettings.webpQuality)")
                                saveSettings()
                            }
                        }
                        
                        // Force description to update with current value
                        Text("\(webpQualityDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 400)
    }
    
    private var mp4QualityDescription: String {
        print("Calculating MP4 quality description for value: \(currentSettings.mp4Quality)")
        let value = currentSettings.mp4Quality
        let closestPreset = mp4QualityPresets.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? mp4QualityPresets[1]
        print("Selected MP4 preset: \(closestPreset.description)")
        return closestPreset.description
    }
    
    private var webpQualityDescription: String {
        print("Calculating WebP quality description for value: \(currentSettings.webpQuality)")
        let value = currentSettings.webpQuality
        let closestPreset = webpQualityPresets.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? webpQualityPresets[2]
        print("Selected WebP preset: \(closestPreset.description)")
        return closestPreset.description
    }
    
    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { currentSettings.soundEnabled },
            set: { newValue in
                currentSettings.soundEnabled = newValue
                saveSettings()
            }
        )
    }
    
    private var mp4PresetBinding: Binding<String> {
        Binding(
            get: { currentSettings.mp4Preset },
            set: { newValue in
                currentSettings.mp4Preset = newValue
                saveSettings()
            }
        )
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(currentSettings) {
            UserDefaultsManager.shared.saveEncodedConversionSettings(encoded)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}

#Preview {
    SettingsView()
} 
