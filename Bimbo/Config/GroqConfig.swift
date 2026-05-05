import Foundation

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
}
