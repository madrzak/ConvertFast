import Foundation
import AppKit

class DependencyManager {
    static let shared = DependencyManager()
    
    private init() {}
    
    func checkDependencies() {
        let dependencies = ["ffmpeg", "cwebp"]
        var missingDeps: [String] = []
        
        for dep in dependencies {
            print("Checking for dependency: \(dep)")
            let exists = checkIfCommandExists(dep)
            UserDefaults.standard.set(exists, forKey: "\(dep)Exists")
            if !exists {
                print("❌ \(dep) not found")
                missingDeps.append(dep)
            } else {
                print("✅ \(dep) found")
            }
        }
        
        if !missingDeps.isEmpty {
            showDependencyAlert(missing: missingDeps)
        }
    }
    
    private func checkIfCommandExists(_ command: String) -> Bool {
        print("🔍 Checking for command: \(command)")
        
        // Check in /opt/homebrew/bin
        let homebrewPath = "/opt/homebrew/bin/\(command)"
        print("  Checking Homebrew path: \(homebrewPath)")
        
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
                    print("  ✅ Command found at: \(resolvedPath)")
                    return true
                }
            }
            
            print("  ❌ Command not found: \(command)")
            return false
        } catch {
            print("  ❌ Error checking for command \(command): \(error)")
            return false
        }
    }
    
    private func showDependencyAlert(missing: [String]) {
        let alert = NSAlert()
        alert.messageText = "Missing Dependencies"
        alert.informativeText = "The following required dependencies are missing:\n\(missing.joined(separator: ", "))\n\nWould you like to install them using Homebrew?"
        alert.alertStyle = NSAlert.Style.warning
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
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        }
    }
    
    func getCommandVersion(_ command: String) -> String {
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