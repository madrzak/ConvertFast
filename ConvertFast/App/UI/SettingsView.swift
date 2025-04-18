import SwiftUI

struct SettingsView: View {
    @AppStorage("ConversionSettings") private var settings: Data = try! JSONEncoder().encode(ConversionSettings())
    @State private var currentSettings: ConversionSettings
    
    init() {
        let decoder = JSONDecoder()
        _currentSettings = State(initialValue: (try? decoder.decode(ConversionSettings.self, from: UserDefaults.standard.data(forKey: "ConversionSettings") ?? Data())) ?? ConversionSettings())
    }
    
    private let qualityPresets: [(value: Int, description: String)] = [
        (18, "Visually Lossless - Highest Quality"),
        (23, "High Quality - Default"),
        (28, "Good Quality - Smaller Size"),
        (35, "Medium Quality - Small Size"),
        (51, "Lowest Quality - Smallest Size")
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
                    HStack {
                        Text("Quality (CRF)")
                        Spacer()
                        Text("\(currentSettings.mp4Quality)")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: mp4QualityBinding, in: 0...51, step: 1)
                        .onChange(of: currentSettings.mp4Quality) { _ in
                            saveSettings()
                        }
                    
                    Text(qualityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Encoding Preset", selection: mp4PresetBinding) {
                        ForEach(encodingPresets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: currentSettings.mp4Preset) { _ in
                        saveSettings()
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Image Conversion Settings").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JPEG Quality")
                        Spacer()
                        Text("\(currentSettings.jpegQuality)")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: jpegQualityBinding, in: 0...100, step: 1)
                        .onChange(of: currentSettings.jpegQuality) { _ in
                            saveSettings()
                        }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 400)
    }
    
    private var qualityDescription: String {
        let value = currentSettings.mp4Quality
        let closestPreset = qualityPresets.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? qualityPresets[1]
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
    
    private var mp4QualityBinding: Binding<Double> {
        Binding(
            get: { Double(currentSettings.mp4Quality) },
            set: { newValue in
                currentSettings.mp4Quality = Int(newValue)
            }
        )
    }
    
    private var mp4PresetBinding: Binding<String> {
        Binding(
            get: { currentSettings.mp4Preset },
            set: { newValue in
                currentSettings.mp4Preset = newValue
            }
        )
    }
    
    private var jpegQualityBinding: Binding<Double> {
        Binding(
            get: { Double(currentSettings.jpegQuality) },
            set: { newValue in
                currentSettings.jpegQuality = Int(newValue)
            }
        )
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(currentSettings) {
            UserDefaults.standard.set(encoded, forKey: "ConversionSettings")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}

struct ConversionSettings: Codable {
    var soundEnabled: Bool = true
    var mp4Quality: Int = 23
    var mp4Preset: String = "fast"
    var jpegQuality: Int = 85
}

#Preview {
    SettingsView()
} 