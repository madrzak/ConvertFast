import Foundation
import AVFoundation

// Add a notification for progress updates
extension Notification.Name {
    static let conversionProgressUpdated = Notification.Name("conversionProgressUpdated")
}

struct ConversionTemplate: Codable {
    let inputExtension: String
    let outputExtension: String
    let command: String
    let deleteOriginal: Bool
}

// Add a struct to track conversion progress
struct ConversionProgress {
    let totalFiles: Int
    let completedFiles: Int
    let currentFileName: String
    let isConverting: Bool
}

class ConversionManager {
    private var templates: [ConversionTemplate] = []
    private var commandPaths: [String: String] = [:]
    private var conversionProgress = ConversionProgress(totalFiles: 0, completedFiles: 0, currentFileName: "", isConverting: false)
    private let conversionQueue = DispatchQueue(label: "com.convertfast.conversion", qos: .userInitiated)
    private var audioPlayer: AVAudioPlayer?
    private var actualConversionsInBatch = 0  // Track actual conversions
    
    init() {
        print("🏗️ Initializing ConversionManager...")
        loadTemplates()
        findCommandPaths()
        setupAudioPlayer()
        print("✅ ConversionManager initialization complete")
    }
    
    private func setupAudioPlayer() {
        if let soundURL = Bundle.main.url(forResource: "ding", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                print("✅ Audio player initialized successfully")
            } catch {
                print("❌ Error initializing audio player: \(error)")
            }
        } else {
            print("❌ Could not find ding.mp3 in any location")
        }
    }
    
    private func playCompletionSound() {
        if let data = UserDefaultsManager.shared.getEncodedConversionSettings(),
           let settings = try? JSONDecoder().decode(ConversionSettings.self, from: data) {
            if settings.soundEnabled {
                audioPlayer?.play()
            }
        } else {
            // Use default value if no settings found
            audioPlayer?.play()
        }
    }
    
    // Add a method to get the current progress
    func getProgress() -> ConversionProgress {
        return conversionProgress
    }
    
    // Add a method to update progress
    private func updateProgress(totalFiles: Int? = nil, completedFiles: Int? = nil, currentFileName: String? = nil, isConverting: Bool? = nil) {
        var newProgress = conversionProgress
        
        if let totalFiles = totalFiles {
            newProgress = ConversionProgress(
                totalFiles: totalFiles,
                completedFiles: conversionProgress.completedFiles,
                currentFileName: conversionProgress.currentFileName,
                isConverting: conversionProgress.isConverting
            )
        }
        
        if let completedFiles = completedFiles {
            let wasConverting = newProgress.isConverting
            let newIsConverting = completedFiles < newProgress.totalFiles
            
            newProgress = ConversionProgress(
                totalFiles: newProgress.totalFiles,
                completedFiles: completedFiles,
                currentFileName: newProgress.currentFileName,
                isConverting: newIsConverting
            )
            
            // Play sound only when all files are completed AND there were actual conversions
            // AND we were previously converting
            if completedFiles == newProgress.totalFiles && actualConversionsInBatch > 0 && wasConverting {
                print("All files completed, playing sound")
                playCompletionSound()
            }
        }
        
        if let currentFileName = currentFileName {
            newProgress = ConversionProgress(
                totalFiles: newProgress.totalFiles,
                completedFiles: newProgress.completedFiles,
                currentFileName: currentFileName,
                isConverting: newProgress.isConverting
            )
        }
        
        if let isConverting = isConverting {
            newProgress = ConversionProgress(
                totalFiles: newProgress.totalFiles,
                completedFiles: newProgress.completedFiles,
                currentFileName: newProgress.currentFileName,
                isConverting: isConverting
            )
        }
        
        conversionProgress = newProgress
        
        // Post notification with updated progress
        NotificationCenter.default.post(
            name: .conversionProgressUpdated,
            object: nil,
            userInfo: ["progress": newProgress]
        )
    }
    
    private func loadTemplates() {
        let defaultTemplates: [ConversionTemplate] = [
            ConversionTemplate(
                inputExtension: "mp3",
                outputExtension: "mp3",
                command: "ffmpeg -i $input -ac 1 -ar 22050 -b:a 64k $output",
                deleteOriginal: true
            ),
            ConversionTemplate(
                inputExtension: "mp4",
                outputExtension: "mp4",
                command: "ffmpeg -i $input -vcodec libx264 -crf $quality -preset $preset -movflags +faststart $output",
                deleteOriginal: false
            ),
            ConversionTemplate(
                inputExtension: "mov",
                outputExtension: "mp4",
                command: "ffmpeg -i $input -vcodec libx264 -crf $quality -preset $preset -movflags +faststart $output",
                deleteOriginal: true
            ),
            ConversionTemplate(
                inputExtension: "mp4",
                outputExtension: "gif",
                command: """
                ffmpeg -i $input -vf "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 $output
                """,
                deleteOriginal: false
            ),
            ConversionTemplate(
                inputExtension: "png",
                outputExtension: "webp",
                command: "cwebp -q $quality $input -o $output",
                deleteOriginal: false
            ),
            ConversionTemplate(
                inputExtension: "jpg",
                outputExtension: "webp",
                command: "magick $input -colorspace sRGB -quality $quality webp:$output",
                deleteOriginal: false
            )
        ]
        
        // Try to load custom templates from JSON file
        if let customTemplatesURL = Bundle.main.url(forResource: "conversion_templates", withExtension: "json"),
           let data = try? Data(contentsOf: customTemplatesURL),
           let customTemplates = try? JSONDecoder().decode([ConversionTemplate].self, from: data) {
            templates = customTemplates
        } else {
            templates = defaultTemplates
        }
    }
    
    private func findCommandPaths() {
        let commands = ["ffmpeg", "cwebp", "magick"]
        
        for command in commands {
            let homebrewPath = "/opt/homebrew/bin/\(command)"
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
                        commandPaths[command] = resolvedPath
                        print("Found path for \(command): \(resolvedPath)")
                    }
                }
            } catch {
                print("Error finding path for \(command): \(error)")
            }
        }
    }
    
    private func executeCommand(_ command: String, completion: @escaping (Bool) -> Void) {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        var outputData = Data()
        
        do {
            try process.run()
            
            // Read output asynchronously
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.count > 0 {
                    outputData.append(data)
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        print("    📋 Command output:")
                        output.components(separatedBy: .newlines).forEach { line in
                            if !line.isEmpty {
                                print("      \(line)")
                            }
                        }
                    }
                }
                
                if data.count == 0 {
                    handle.readabilityHandler = nil
                }
            }
            
            // Wait for completion in background
            conversionQueue.async {
                process.waitUntilExit()
                
                // Print final error output if any
                if let finalOutput = String(data: outputData, encoding: .utf8), !finalOutput.isEmpty {
                    print("    ❌ Final error output:")
                    finalOutput.components(separatedBy: .newlines).forEach { line in
                        if !line.isEmpty {
                            print("      \(line)")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        self.actualConversionsInBatch += 1  // Increment only on successful conversion
                    }
                    completion(process.terminationStatus == 0)
                }
            }
        } catch {
            print("    ❌ Error executing command: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func processCommand(_ command: String, input: String, output: String) -> String {
        let settings: ConversionSettings
        if let data = UserDefaultsManager.shared.getEncodedConversionSettings(),
           let decoded = try? JSONDecoder().decode(ConversionSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ConversionSettings() // Use default values
        }
        
        print("  🔧 Processing command with settings:")
        print("    - soundEnabled: \(settings.soundEnabled)")
        print("    - mp4Quality: \(settings.mp4Quality)")
        print("    - mp4Preset: \(settings.mp4Preset)")
        print("    - webpQuality: \(settings.webpQuality)")
        
        var processedCommand = command
            .replacingOccurrences(of: "$input", with: input)
            .replacingOccurrences(of: "$output", with: output)
        
        // Handle quality setting
        if command.contains("cwebp") || command.contains("magick") {
            processedCommand = processedCommand.replacingOccurrences(of: "$quality", with: String(settings.webpQuality))
            print("    📊 Using WebP quality: \(settings.webpQuality)")
        } else {
            processedCommand = processedCommand.replacingOccurrences(of: "$quality", with: String(settings.mp4Quality))
        }
        
        // Handle preset
        processedCommand = processedCommand.replacingOccurrences(of: "$preset", with: settings.mp4Preset)
        
        print("    🛠️ Processed command: \(processedCommand)")
        return processedCommand
    }
    
    func processFile(at url: URL, isForceConversion: Bool = false) {
        conversionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            let fileName = url.deletingPathExtension().lastPathComponent
            
            // Update progress to show we're starting a new file
            DispatchQueue.main.async {
                self.updateProgress(currentFileName: url.lastPathComponent, isConverting: true)
            }
            
            // Skip if the file is already optimized, unless it's a force conversion
            if fileName.hasSuffix("_optimized") && !isForceConversion {
                print("  ⏭️ Skipping already optimized file: \(url.lastPathComponent)")
                DispatchQueue.main.async {
                    self.updateProgress(completedFiles: self.conversionProgress.completedFiles + 1, isConverting: false)
                }
                return
            }
            
            print("  🔄 Processing file: \(url.lastPathComponent) (extension: \(fileExtension))")
            
            guard let template = self.templates.first(where: { $0.inputExtension == fileExtension }) else {
                print("    ❌ No conversion template found for extension: \(fileExtension)")
                DispatchQueue.main.async {
                    self.updateProgress(completedFiles: self.conversionProgress.completedFiles + 1, isConverting: false)
                }
                return
            }
            
            // Create output URL with appropriate suffix
            let outputURL: URL
            if fileExtension == "mp4" && template.outputExtension == "mp4" {
                let baseFileName = fileName.replacingOccurrences(of: "_optimized", with: "")
                                       .replacingOccurrences(of: "_force", with: "")
                
                // If it's a force conversion of an already optimized file, use _force suffix
                let suffix = (fileName.hasSuffix("_optimized") && isForceConversion) ? "_optimized_force" : "_optimized"
                outputURL = url.deletingLastPathComponent()
                    .appendingPathComponent(baseFileName + suffix)
                    .appendingPathExtension(template.outputExtension)
            } else {
                // For non-MP4 files or when converting to a different format
                var newURL = url.deletingPathExtension().appendingPathExtension(template.outputExtension)
                
                // If file exists and it's a force conversion, find a unique name
                if isForceConversion && FileManager.default.fileExists(atPath: newURL.path) {
                    var counter = 1
                    repeat {
                        newURL = url.deletingLastPathComponent()
                            .appendingPathComponent("\(fileName)_\(counter)")
                            .appendingPathExtension(template.outputExtension)
                        counter += 1
                    } while FileManager.default.fileExists(atPath: newURL.path)
                }
                outputURL = newURL
            }
            
            print("    📝 Will convert to: \(outputURL.lastPathComponent)")
            
            // Skip if output file already exists and it's not a force conversion
            if !isForceConversion && FileManager.default.fileExists(atPath: outputURL.path) {
                print("    ⚠️ Output file already exists, skipping: \(outputURL.lastPathComponent)")
                DispatchQueue.main.async {
                    self.updateProgress(completedFiles: self.conversionProgress.completedFiles + 1, isConverting: false)
                }
                return
            }
            
            // Debug print settings
            print("    ⚙️ Current settings:")
            let settings = UserDefaultsManager.shared.getConversionSettings() ?? [:]
            print("      - mp4Quality: \(settings["mp4Quality"] ?? "not set")")
            print("      - mp4Preset: \(settings["mp4Preset"] ?? "not set")")
            
            // Process the command using the dedicated method
            var command = self.processCommand(
                template.command,
                input: "\"\(url.path)\"",
                output: "\"\(outputURL.path)\""
            )
            
            // Replace command names with full paths
            for (cmd, path) in self.commandPaths {
                command = command.replacingOccurrences(of: cmd, with: "\"\(path)\"")
            }
            
            print("    🛠️ Executing command: \(command)")
            
            self.executeCommand(command) { success in
                if success {
                    print("    ✅ Conversion successful: \(outputURL.lastPathComponent)")
                    if template.deleteOriginal {
                        do {
                            try FileManager.default.removeItem(at: url)
                            print("    🗑️ Original file deleted: \(url.lastPathComponent)")
                        } catch {
                            print("    ⚠️ Failed to delete original file: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("    ❌ Conversion failed for: \(url.lastPathComponent)")
                }
                
                // Update progress when file is completed
                DispatchQueue.main.async {
                    self.updateProgress(completedFiles: self.conversionProgress.completedFiles + 1, isConverting: false)
                }
            }
        }
    }
    
    func getCommandPath(_ command: String) -> String {
        return commandPaths[command] ?? "/opt/homebrew/bin/\(command)"
    }
    
    // Add a method to start a batch conversion
    func startBatchConversion(files: [URL], isForceConversion: Bool = false) {
        // Reset the conversion counter at the start of each batch
        actualConversionsInBatch = 0
        
        // Don't show progress if there are no files
        if files.isEmpty {
            DispatchQueue.main.async {
                self.updateProgress(totalFiles: 0, completedFiles: 0, currentFileName: "", isConverting: false)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.updateProgress(totalFiles: files.count, completedFiles: 0, currentFileName: "", isConverting: true)
        }
        
        // Process each file in the batch
        for (index, url) in files.enumerated() {
            processFile(at: url, isForceConversion: isForceConversion)
        }
    }
} 
