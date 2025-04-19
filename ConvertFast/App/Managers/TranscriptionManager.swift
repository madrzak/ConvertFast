import Foundation

enum TranscriptionError: Error {
    case audioExtractionFailed
    case transcriptionFailed
    case subtitleGenerationFailed
    case subtitleBurningFailed
    case jsonParsingFailed
}

struct WhisperSegment: Codable {
    let start: Double
    let end: Double
    let text: String
}

struct WhisperTranscript: Codable {
    let segments: [WhisperSegment]
}

final class TranscriptionManager {
    static let shared = TranscriptionManager()
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    private let conversionManager: ConversionManager
    private let whisperModelPath: String
    
    private init() {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("ConvertFastTranscription")
        whisperModelPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".cache/whisper").path
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(atPath: whisperModelPath, withIntermediateDirectories: true)
        conversionManager = ConversionManager()
        
        // Ensure model is downloaded
        Task {
            try? await downloadWhisperModelIfNeeded()
        }
    }
    
    private func downloadWhisperModelIfNeeded() async throws {
        print("    📥 Checking Whisper model...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: conversionManager.getCommandPath("whisper"))
        process.arguments = [
            "--model", "medium",
            "--model_dir", whisperModelPath,
            "--download_only"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("    ✅ Whisper model ready")
        } else {
            print("    ⚠️ Failed to download Whisper model")
        }
    }
    
    func transcribeAndBurnSubtitles(inputVideoPath: String) async throws -> String {
        print("\n🎙️ Starting transcription workflow...")
        print("    📝 Input video: \(inputVideoPath)")
        
        // Check if whisper is available
        guard UserDefaultsManager.shared.whisperExists else {
            print("❌ Whisper is not installed. Please install it using Homebrew: brew install whisper")
            throw TranscriptionError.transcriptionFailed
        }
        
        let inputURL = URL(fileURLWithPath: inputVideoPath)
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        
        // Create working directory for this transcription
        let workingDir = tempDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        print("    📁 Created working directory: \(workingDir.path)")
        
        // Step 1: Extract audio to WAV
        let wavPath = workingDir.appendingPathComponent("\(fileName).wav").path
        print("    🔊 Extracting audio to: \(wavPath)")
        try await extractAudio(from: inputVideoPath, to: wavPath)
        
        // Verify the WAV file exists and has content
        guard fileManager.fileExists(atPath: wavPath),
              let wavAttrs = try? fileManager.attributesOfItem(atPath: wavPath),
              (wavAttrs[.size] as? UInt64 ?? 0) > 0 else {
            throw TranscriptionError.audioExtractionFailed
        }
        
        // Step 2: Transcribe using Whisper
        let jsonPath = workingDir.appendingPathComponent("\(fileName).json").path
        print("    🗣️ Transcribing audio to: \(jsonPath)")
        try await transcribeAudio(wavPath: wavPath, outputPath: jsonPath)
        
        // Step 3: Generate ASS subtitles
        let assPath = workingDir.appendingPathComponent("\(fileName).ass").path
        print("    📝 Generating subtitles at: \(assPath)")
        try await generateSubtitles(from: jsonPath, to: assPath)
        
        // Step 4: Burn subtitles into video
        let outputPath = inputURL.deletingLastPathComponent().appendingPathComponent("\(fileName)-subtitled.mp4").path
        print("    🎬 Creating final video with subtitles: \(outputPath)")
        try await burnSubtitles(videoPath: inputVideoPath, subtitlesPath: assPath, outputPath: outputPath)
        
        // Cleanup
        print("    🧹 Cleaning up temporary files...")
        try? fileManager.removeItem(at: workingDir)
        
        print("✅ Transcription workflow completed successfully!")
        return outputPath
    }
    
    private func extractAudio(from videoPath: String, to wavPath: String) async throws {
        print("    🎙️ Extracting audio from video...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: conversionManager.getCommandPath("ffmpeg"))
        process.arguments = [
            "-y",  // Force overwrite
            "-i", videoPath,
            "-vn",  // Disable video
            "-acodec", "pcm_s16le",  // Force PCM 16-bit output
            "-ar", "16000",  // Set sample rate
            "-ac", "1",  // Force mono
            "-af", "aresample=async=1:min_hard_comp=0.100000:first_pts=0",  // Handle async audio
            wavPath
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Create a pipe for stdin to prevent waiting for user input
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        
        var outputData = Data()
        
        // Read output asynchronously
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                outputData.append(data)
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("    📋 FFmpeg output:")
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
        
        try process.run()
        
        // Wait for completion
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                // Print final error output if any
                if let finalOutput = String(data: outputData, encoding: .utf8), !finalOutput.isEmpty {
                    print("    📋 Final FFmpeg output:")
                    finalOutput.components(separatedBy: .newlines).forEach { line in
                        if !line.isEmpty {
                            print("      \(line)")
                        }
                    }
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranscriptionError.audioExtractionFailed)
                }
            }
        }
    }
    
    private func transcribeAudio(wavPath: String, outputPath: String) async throws {
        print("    🎙️ Transcribing audio with Whisper...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: conversionManager.getCommandPath("whisper"))
        process.arguments = [
            wavPath,
            "--model", "medium",
            "--model_dir", whisperModelPath,
            "--language", "en",
            "--output_format", "json",
            "--output_dir", (outputPath as NSString).deletingLastPathComponent,
            "--word_timestamps", "True"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Create a pipe for stdin to prevent waiting for user input
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        
        var outputData = Data()
        
        // Read output asynchronously
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                outputData.append(data)
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("    📋 Whisper output:")
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
        
        try process.run()
        
        // Wait for completion
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                // Print final error output if any
                if let finalOutput = String(data: outputData, encoding: .utf8), !finalOutput.isEmpty {
                    print("    📋 Final Whisper output:")
                    finalOutput.components(separatedBy: .newlines).forEach { line in
                        if !line.isEmpty {
                            print("      \(line)")
                        }
                    }
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed)
                }
            }
        }
    }
    
    private func generateSubtitles(from jsonPath: String, to assPath: String) async throws {
        print("    🎙️ Generating ASS subtitles...")
        // Read and parse the JSON file
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        guard let transcript = try? JSONDecoder().decode(WhisperTranscript.self, from: jsonData) else {
            throw TranscriptionError.jsonParsingFailed
        }
        
        // Generate ASS subtitle content
        var assContent = """
        [Script Info]
        Title: Auto-generated by ConvertFast
        ScriptType: v4.00+
        Collisions: Normal
        PlayResX: 1920
        PlayResY: 1080
        
        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,3,2,20,20,20,1
        
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        
        """
        
        // Convert segments to ASS format
        for segment in transcript.segments {
            let startTime = formatTime(seconds: segment.start)
            let endTime = formatTime(seconds: segment.end)
            let text = cleanText(segment.text)
            
            assContent += "Dialogue: 0,\(startTime),\(endTime),Default,,0,0,0,,\(text)\n"
        }
        
        // Write to file
        try assContent.write(to: URL(fileURLWithPath: assPath), atomically: true, encoding: .utf8)
        print("    ✅ Generated ASS subtitles at: \(assPath)")
    }
    
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%02d:%05.2f", hours, minutes, secs)
    }
    
    private func cleanText(_ text: String) -> String {
        return text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func burnSubtitles(videoPath: String, subtitlesPath: String, outputPath: String) async throws {
        print("    🎙️ Burning subtitles into video...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: conversionManager.getCommandPath("ffmpeg"))
        process.arguments = [
            "-y",  // Force overwrite
            "-i", videoPath,
            "-vf", "ass=\(subtitlesPath)",
            "-c:a", "copy",
            outputPath
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Create a pipe for stdin to prevent waiting for user input
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        
        var outputData = Data()
        
        // Read output asynchronously
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                outputData.append(data)
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("    📋 FFmpeg output:")
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
        
        try process.run()
        
        // Wait for completion
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                // Print final error output if any
                if let finalOutput = String(data: outputData, encoding: .utf8), !finalOutput.isEmpty {
                    print("    📋 Final FFmpeg output:")
                    finalOutput.components(separatedBy: .newlines).forEach { line in
                        if !line.isEmpty {
                            print("      \(line)")
                        }
                    }
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranscriptionError.subtitleBurningFailed)
                }
            }
        }
    }
} 