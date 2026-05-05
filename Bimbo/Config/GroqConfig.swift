import Foundation

// MARK: - Setup con xcconfig (recomendado para produccion)
//
// 1. En Xcode: Project > Info > Configurations > selecciona GroqConfig.xcconfig para Debug y Release.
// 2. En Info.plist agrega: GROQ_API_KEY = $(GROQ_API_KEY)
// 3. Define la API key solo en GroqConfig.xcconfig, que debe quedarse fuera de git.

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
