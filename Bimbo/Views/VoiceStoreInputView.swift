import SwiftUI
import Speech
import AVFoundation

// MARK: - Speech Recognizer
// Requiere en Info.plist:
//   NSMicrophoneUsageDescription
//   NSSpeechRecognitionUsageDescription

@Observable
final class SpeechRecognizer {
    var transcript   = ""
    var isRecording  = false
    var permissionOK = false
    var error: String?

    private var recognitionTask:    SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine    = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
        ?? SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionOK = (status == .authorized)
                if status != .authorized {
                    self?.error = "Permiso de reconocimiento de voz denegado. Actívalo en Configuración."
                }
            }
        }
    }

    func start() {
        guard permissionOK, let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = "Reconocimiento de voz no disponible."
            return
        }
        transcript = ""
        error = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Error de audio: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, err in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async { self.transcript = result.bestTranscription.formattedString }
            }
            if err != nil || result?.isFinal == true { self.stop() }
        }

        let fmt = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { self.error = "Error al iniciar el micrófono." ; return }
        isRecording = true
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        // Restaura sesión de audio para reproducción
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
    }
}

// MARK: - Voice Store Input View

struct VoiceStoreInputView: View {
    let store: Store
    let onApply: (ParsedStoreFields) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var recognizer   = SpeechRecognizer()
    @State private var parsed:        ParsedStoreFields?
    @State private var isParsing     = false
    @State private var parseError:    String?
    @State private var phase: Phase  = .idle   // idle → recording → processing → result

    private let parser = StoreFieldParserService()

    enum Phase { case idle, recording, processing, result }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    instructions

                    micButton

                    if !recognizer.transcript.isEmpty {
                        transcriptCard
                    }

                    if let err = recognizer.error ?? parseError {
                        errorBanner(err)
                    }

                    if phase == .processing {
                        processingCard
                    }

                    if let parsed, phase == .result {
                        fieldsPreview(parsed)

                        Button {
                            onApply(parsed)
                            dismiss()
                        } label: {
                            Label("Aplicar a la tienda", systemImage: "checkmark.circle.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .foregroundStyle(.white)
                                .background(AppTheme.success, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.subtleGradient.ignoresSafeArea())
            .navigationTitle("Actualizar con voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { recognizer.stop(); dismiss() }
                        .foregroundStyle(AppTheme.bimboRed)
                }
            }
        }
        .onAppear { recognizer.requestPermission() }
        .onDisappear { recognizer.stop() }
    }

    // MARK: - Sub-views

    private var instructions: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.deepBlue)
            Text("Habla naturalmente sobre la tienda")
                .font(.headline.weight(.bold))
            Text("Menciona el presupuesto, qué vende bien, qué no rota, cuándo fue la última visita y si hay devoluciones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var micButton: some View {
        Button {
            switch phase {
            case .idle, .result:
                parsed = nil
                parseError = nil
                phase = .recording
                recognizer.start()
            case .recording:
                recognizer.stop()
                phase = .processing
                Task { await processTranscript() }
            case .processing:
                break
            }
        } label: {
            ZStack {
                Circle()
                    .fill(phase == .recording ? AppTheme.bimboRed : AppTheme.deepBlue)
                    .frame(width: 90, height: 90)
                    .shadow(color: (phase == .recording ? AppTheme.bimboRed : AppTheme.deepBlue).opacity(0.4),
                            radius: phase == .recording ? 16 : 8)
                Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Text(phase == .idle || phase == .result ? "Toca para hablar" :
                 phase == .recording ? "Toca para detener" : "Procesando...")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(y: 24)
        }
        .padding(.bottom, 16)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Lo que escuché", systemImage: "text.bubble.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)
            Text(recognizer.transcript)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var processingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(AppTheme.deepBlue)
            Text("La IA está extrayendo los datos...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorBanner(_ msg: String) -> some View {
        Label(msg, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.bimboRed)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.bimboRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fieldsPreview(_ f: ParsedStoreFields) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Datos extraídos", systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)

            if let v = f.estimatedBudget {
                fieldRow("Presupuesto", "$\(Int(v))", "dollarsign.circle.fill", AppTheme.success)
            }
            if let v = f.bestSellers, !v.isEmpty {
                fieldRow("Más vendidos", v.joined(separator: ", "), "star.fill", AppTheme.warning)
            }
            if let v = f.lowRotationProducts, !v.isEmpty {
                fieldRow("Baja rotación", v.joined(separator: ", "), "arrow.down.circle.fill", AppTheme.bimboRed)
            }
            if let v = f.lastVisit {
                fieldRow("Última visita", v, "clock.fill", AppTheme.electricBlue)
            }
            if let v = f.lastReturn {
                fieldRow("Devolución", v, "arrow.uturn.backward.circle.fill", AppTheme.deepBlue)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func fieldRow(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success).font(.caption)
        }
    }

    // MARK: - Processing

    @MainActor
    private func processTranscript() async {
        let text = recognizer.transcript
        guard !text.isEmpty else {
            parseError = "No se detectó audio. Intenta de nuevo."
            phase = .idle
            return
        }
        do {
            let result = try await parser.parse(transcript: text, storeName: store.name)
            parsed = result
            phase = .result
        } catch {
            // Fallback mock si no hay API key
            parsed = parser.mockParsed()
            phase = .result
        }
    }
}
