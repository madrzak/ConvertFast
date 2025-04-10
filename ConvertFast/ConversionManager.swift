import Foundation

struct ConversionTemplate: Codable {
    let inputExtension: String
    let outputExtension: String
    let command: String
    let deleteOriginal: Bool
}

class ConversionManager {
    private var templates: [ConversionTemplate] = []
    private var commandPaths: [String: String] = [:]
    
    init() {
        loadTemplates()
        findCommandPaths()
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
                command: "ffmpeg -i $input -vcodec libx264 -crf 23 -preset fast -movflags +faststart $output",
                deleteOriginal: true
            ),
            ConversionTemplate(
                inputExtension: "mov",
                outputExtension: "mp4",
                command: "ffmpeg -i $input -vcodec libx264 -crf 23 -preset fast -movflags +faststart $output",
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
                command: "cwebp -q 80 $input -o $output",
                deleteOriginal: false
            ),
            ConversionTemplate(
                inputExtension: "jpg",
                outputExtension: "webp",
                command: "cwebp -q 80 $input -o $output",
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
        let commands = ["ffmpeg", "cwebp"]
        
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
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Capture and log command output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("    📋 Command output:")
                output.components(separatedBy: .newlines).forEach { line in
                    if !line.isEmpty {
                        print("      \(line)")
                    }
                }
            }
            
            completion(process.terminationStatus == 0)
        } catch {
            print("    ❌ Error executing command: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func testCommands() {
        print("\n🔍 Testing command execution:")
        
        // Test ffmpeg
        print("\nTesting ffmpeg:")
        if let ffmpegPath = commandPaths["ffmpeg"] {
            print("    Using ffmpeg path: \(ffmpegPath)")
            executeCommand("\"\(ffmpegPath)\" -version") { success in
                if success {
                    print("✅ ffmpeg command executed successfully")
                } else {
                    print("❌ ffmpeg command execution failed")
                }
            }
        } else {
            print("❌ ffmpeg path not found")
        }
        
        // Test cwebp
        print("\nTesting cwebp:")
        if let cwebpPath = commandPaths["cwebp"] {
            print("    Using cwebp path: \(cwebpPath)")
            executeCommand("\"\(cwebpPath)\" -version") { success in
                if success {
                    print("✅ cwebp command executed successfully")
                } else {
                    print("❌ cwebp command execution failed")
                }
            }
        } else {
            print("❌ cwebp path not found")
        }
    }
    
    func processFile(at url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        print("  🔄 Processing file: \(url.lastPathComponent) (extension: \(fileExtension))")
        
        guard let template = templates.first(where: { $0.inputExtension == fileExtension }) else {
            print("    ❌ No conversion template found for extension: \(fileExtension)")
            return
        }
        
        let outputURL = url.deletingPathExtension().appendingPathExtension(template.outputExtension)
        print("    📝 Will convert to: \(outputURL.lastPathComponent)")
        
        // Skip if output file already exists
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            print("    ⚠️ Output file already exists, skipping: \(outputURL.lastPathComponent)")
            return
        }
        
        var command = template.command
            .replacingOccurrences(of: "$input", with: "\"\(url.path)\"")
            .replacingOccurrences(of: "$output", with: "\"\(outputURL.path)\"")
        
        // Replace command names with full paths
        for (cmd, path) in commandPaths {
            command = command.replacingOccurrences(of: cmd, with: "\"\(path)\"")
        }
        
        print("    🛠️ Executing command: \(command)")
        
        executeCommand(command) { success in
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
        }
    }
} 