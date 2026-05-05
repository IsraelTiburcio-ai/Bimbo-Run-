import AVFoundation
import Observation

@Observable
final class VoiceService: NSObject {

    static let shared = VoiceService()

    // MARK: - Estado observable
    var isPlaying  = false
    var isLoading  = false
    var isEnabled: Bool = {
        let stored = UserDefaults.standard.object(forKey: "bimbo.voiceEnabled")
        return stored == nil ? true : UserDefaults.standard.bool(forKey: "bimbo.voiceEnabled")
    }()

    // MARK: - Privado
    private var player: AVAudioPlayer?

    private override init() {
        super.init()
        configureAudioSession()
    }

    // MARK: - API pública

    func speak(_ text: String) async {
        guard isEnabled, !text.isEmpty else { return }
        if isPlaying { stop() }

        await MainActor.run { isLoading = true }

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
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                isPlaying = false
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "bimbo.voiceEnabled")
        if !enabled { stop() }
    }

    // MARK: - ElevenLabs

    private func fetchAudio(_ text: String) async throws -> Data {
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(ElevenLabsConfig.voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ElevenLabsConfig.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VoiceError.apiError
        }
        return data
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}

// MARK: - Error

enum VoiceError: Error {
    case apiError
    case disabled
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
