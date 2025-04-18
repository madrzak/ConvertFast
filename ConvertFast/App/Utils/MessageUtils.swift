import Foundation

class MessageUtils {
    static let shared = MessageUtils()
    
    private init() {}
    
    func getRandomIdleMessage() -> String {
        let idleMessages = [
            "Watching folder for signs of life...",
            "Ready to convert your media...",
            "Idle mode: coffee break",
            "Monitoring for new files...",
            "Standing by for conversion duty...",
            "Ready to convert...",
            "Waiting for files...",
            "Idle...",
            "Drop files here..."
        ]
        return idleMessages.randomElement() ?? "Watching folder for signs of life..."
    }
} 