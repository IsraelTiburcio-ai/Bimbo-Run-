import SwiftUI

struct ScanView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    @State private var isScanning = false
    @State private var messageIndex = 0
    @State private var pulse = false

    private let messages = [
        "Leyendo QR...",
        "Validando caducidades...",
        "Cruzando historial de pedido...",
        "Calculando recomendacion..."
    ]

    var body: some View {
        VStack(spacing: 22) {
            header
            cameraMock
            statusCard
            Spacer(minLength: 8)
            PrimaryButton(title: isScanning ? "Procesando anaquel" : "Iniciar escaneo", systemImage: isScanning ? nil : "viewfinder", isLoading: isScanning) {
                startScan()
            }
            .disabled(isScanning)
        }
        .padding(18)
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle("Escanear anaquel")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.store(for: storeId)?.name ?? "Escaneo rapido")
                .font(.title.weight(.bold))
            Text("Simula lectura de QR, caducidades e historial antes de generar la recomendacion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cameraMock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.gradient)
            ScanGrid()
                .stroke(.white.opacity(0.22), lineWidth: 1)
                .padding(24)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isScanning ? AppTheme.bimboRed : .white.opacity(0.72), lineWidth: 3)
                .padding(18)
                .scaleEffect(pulse ? 1.012 : 1)

            if isScanning {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(messages[messageIndex])
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel("Camara simulada con cuadricula para escanear anaquel")
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: isScanning ? "sparkles" : "qrcode.viewfinder")
                .foregroundStyle(isScanning ? AppTheme.bimboRed : AppTheme.deepBlue)
            Text(isScanning ? messages[messageIndex] : "Listo para iniciar escaneo")
                .font(.headline.weight(.semibold))
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func startScan() {
        guard !isScanning else { return }
        isScanning = true
        viewModel.startVisit(storeId: storeId)

        Task { @MainActor in
            // Llama a Groq y anima los mensajes en paralelo
            async let aiTask: Void = viewModel.generateAIRecommendation(storeId: storeId)

            for index in messages.indices {
                withAnimation(.easeInOut(duration: 0.22)) {
                    messageIndex = index
                }
                try? await Task.sleep(for: .milliseconds(700))
            }

            await aiTask // espera a que termine si aun no ha respondido
            path.append(.recommendation(storeId))
        }
    }
}

private struct ScanGrid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 1...2 {
                let ratio = CGFloat(index) / 3
                let x = rect.minX + rect.width * ratio
                let y = rect.minY + rect.height * ratio
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}
