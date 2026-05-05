import AVFoundation
import Observation

@Observable
final class VoiceService: NSObject {

    static let shared = VoiceService()

    // MARK: - Estado observable
    var isPlaying  = false
    var isLoading  = false
    var lastErrorMessage: String?
    var isEnabled: Bool = {
        let stored = UserDefaults.standard.object(forKey: "bimbo.voiceEnabled")
        return stored == nil ? true : UserDefaults.standard.bool(forKey: "bimbo.voiceEnabled")
    }()

    // MARK: - Privado
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - API pública

    func speak(_ text: String) async {
        guard isEnabled, !text.isEmpty else { return }
        if isPlaying { stop() }

        await MainActor.run {
            isLoading = true
            lastErrorMessage = nil
        }

        do {
            let data = try await fetchAudio(text)
            await MainActor.run {
                isLoading = false
                do {
                    player = try AVAudioPlayer(data: data)
                    player?.delegate = self
                    player?.prepareToPlay()
                    player?.play()
                    isPlaying = true
                } catch {
                    isPlaying = false
                    speakLocally(text, reason: "No se pudo reproducir audio de ElevenLabs. Usando voz local.")
                }
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await MainActor.run {
                isLoading = false
                isPlaying = false
                speakLocally(text, reason: message)
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "bimbo.voiceEnabled")
        if !enabled { stop() }
    }

    // MARK: - ElevenLabs

    private func fetchAudio(_ text: String) async throws -> Data {
        guard ElevenLabsConfig.isConfigured else {
            throw VoiceError.missingAPIKey
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(ElevenLabsConfig.voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ElevenLabsConfig.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": ElevenLabsConfig.model,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VoiceError.apiError(statusCode: -1, message: "Respuesta sin HTTPURLResponse")
        }
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? "Sin detalle del servidor"
            throw VoiceError.apiError(statusCode: http.statusCode, message: String(bodyText.prefix(180)))
        }
        return data
    }

    @MainActor
    private func speakLocally(_ text: String, reason: String) {
        lastErrorMessage = reason
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
        isPlaying = true
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true)
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isPlaying = false }
    }
}

// MARK: - Error

enum VoiceError: Error {
    case missingAPIKey
    case apiError(statusCode: Int, message: String)
    case disabled
}

extension VoiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ElevenLabs sin API key. Usando voz local del iPhone."
        case .apiError(let statusCode, let message):
            return "ElevenLabs respondio \(statusCode): \(message). Usando voz local del iPhone."
        case .disabled:
            return "Voz desactivada."
        }
    }
}

// MARK: - Componentes SwiftUI reutilizables

import SwiftUI

/// Botón play/stop genérico para cualquier texto
struct VoicePlayButton: View {
    let text: String
    var label: String = "Escuchar"

    private var voice: VoiceService { VoiceService.shared }

    var body: some View {
        Button {
            if voice.isPlaying { voice.stop() }
            else { Task { await voice.speak(text) } }
        } label: {
            HStack(spacing: 8) {
                if voice.isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image(systemName: voice.isPlaying ? "stop.circle.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(voice.isLoading ? "Preparando voz..." : voice.isPlaying ? "Detener" : label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .buttonStyle(.borderedProminent)
        .tint(voice.isPlaying ? .red : AppTheme.deepBlue)
        .disabled(voice.isLoading || !voice.isEnabled)
    }
}

/// Toggle on/off de voz con persistencia
struct VoiceToggleRow: View {
    private var voice: VoiceService { VoiceService.shared }

    var body: some View {
        HStack {
            Image(systemName: voice.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .foregroundStyle(voice.isEnabled ? AppTheme.deepBlue : .secondary)
            Text("Voz")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Toggle("", isOn: Binding(
                get: { voice.isEnabled },
                set: { voice.setEnabled($0) }
            ))
            .tint(AppTheme.deepBlue)
            .labelsHidden()
        }
    }
}
