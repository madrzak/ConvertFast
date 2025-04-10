import Foundation

struct ConversionTemplate: Codable {
    let inputExtension: String
    let outputExtension: String
    let command: String
    let deleteOriginal: Bool
}

class ConversionManager {
    private var templates: [ConversionTemplate] = []
    
    init() {
        loadTemplates()
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
    
    func processFile(at url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        
        guard let template = templates.first(where: { $0.inputExtension == fileExtension }) else {
            return
        }
        
        let outputURL = url.deletingPathExtension().appendingPathExtension(template.outputExtension)
        
        // Skip if output file already exists
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            return
        }
        
        let command = template.command
            .replacingOccurrences(of: "$input", with: url.path)
            .replacingOccurrences(of: "$output", with: outputURL.path)
        
        executeCommand(command) { success in
            if success && template.deleteOriginal {
                try? FileManager.default.removeItem(at: url)
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
            completion(process.terminationStatus == 0)
        } catch {
            completion(false)
        }
    }
} 