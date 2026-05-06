import Foundation

// MARK: - Groq configuration
// The API key is loaded from Info.plist (via xcconfig) or from environment.

enum GroqConfig {
    static var apiKey: String {
        if let key = Bundle.main.infoDictionary?["GROQ_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"],
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static var defaultChatModel: String {
        // Allow override from Info.plist or env var; otherwise provide a safe default
        if let model = Bundle.main.infoDictionary?["GROQ_CHAT_MODEL"] as? String,
           !model.isEmpty, !model.hasPrefix("$(") {
            return model
        }
        if let model = ProcessInfo.processInfo.environment["GROQ_CHAT_MODEL"],
           !model.isEmpty, !model.hasPrefix("$(") {
            return model
        }
        // Groq recommended general-purpose chat model
        return "llama-3.1-70b-versatile"
    }
}
