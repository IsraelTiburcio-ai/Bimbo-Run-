import Foundation

enum ElevenLabsConfig {
    private static let hardcodedDemoKey = "sk_1aec776eb83bdc560c524b77580bb27a78c23f70527b842f"

    static var apiKey: String {
        if let key = Bundle.main.infoDictionary?["ELEVENLABS_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"],
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return hardcodedDemoKey
    }

    static let voiceId = "qWWAqFomnJ99VwQLREfT"
    static let model   = "eleven_multilingual_v2"

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }
}
