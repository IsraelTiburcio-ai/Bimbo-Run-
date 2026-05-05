import SwiftUI
import AudioToolbox
import CoreImage.CIFilterBuiltins
import UIKit

struct ScanView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    @State private var pulse = false
    @State private var liveWarning: ScannedProduct?
    @State private var isFinishing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                scannerCard
                liveStatusCard
                scannedList
                sampleQRCodes
                PrimaryButton(title: isFinishing ? "Generando recomendacion" : "Finalizar escaneo", systemImage: isFinishing ? nil : "sparkles", isLoading: isFinishing) {
                    finishScan()
                }
                .disabled(isFinishing)
            }
            .padding(18)
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle("Escanear productos")
        .onAppear {
            viewModel.resetScan(storeId: storeId)
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.store(for: storeId)?.name ?? "Escaneo rapido")
                .font(.title.weight(.bold))
            Text("Pasa el celular sobre los QRs de producto. Cada lectura se valida al instante contra caducidad y lote.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scannerCard: some View {
        ZStack {
            QRScannerView { payload in
                handleDetectedPayload(payload)
            }
            .background(Color.black)

            ScanGrid()
                .stroke(.white.opacity(0.26), lineWidth: 1)
                .padding(28)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(liveWarning == nil ? .white.opacity(0.72) : AppTheme.bimboRed, lineWidth: 3)
                .padding(18)
                .scaleEffect(pulse ? 1.012 : 1)

            VStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 38, weight: .semibold))
                Text("Centra el QR a 15-25 cm")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack {
                Spacer()
                Text(liveWarning == nil ? "Scanner QR en tiempo real" : "Alerta de caducidad detectada")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background((liveWarning == nil ? Color.black.opacity(0.45) : AppTheme.bimboRed.opacity(0.88)), in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityLabel("Camara con scanner continuo de codigos QR")
    }

    private var liveStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: liveWarning == nil ? "qrcode.viewfinder" : "exclamationmark.triangle.fill")
                    .foregroundStyle(liveWarning == nil ? AppTheme.deepBlue : AppTheme.bimboRed)
                Text(liveWarning == nil ? "Listo para detectar productos" : "Retiro recomendado en vivo")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(viewModel.scannedProducts.count)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.deepBlue)
            }

            if let liveWarning {
                Text("\(liveWarning.name) lote \(liveWarning.batch) - \(liveWarning.expirationRisk.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.bimboRed)
            }

            ForEach(viewModel.scanAlerts.prefix(2), id: \.self) { alert in
                Text(alert)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scannedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Productos detectados", systemImage: "shippingbox.fill")
                .font(.headline.weight(.bold))

            if viewModel.scannedProducts.isEmpty {
                Text("Aun no hay productos escaneados.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.scannedProducts) { product in
                    HStack(spacing: 12) {
                        Image(systemName: product.expirationRisk == .safe ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(product.expirationRisk == .safe ? AppTheme.success : AppTheme.bimboRed)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.name)
                                .font(.headline.weight(.semibold))
                            Text("SKU \(product.sku) - Lote \(product.batch) - \(product.expirationRisk.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(product.quantity) pz")
                            .font(.caption.weight(.bold))
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sampleQRCodes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("QRs de prueba", systemImage: "qrcode")
                .font(.headline.weight(.bold))
            Text("25 codigos para demo. Los caducados disparan pitido, vibracion y alerta visual al instante.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.sampleProducts) { sample in
                    QRTestCodeView(sample: sample)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func handleDetectedPayload(_ payload: String) {
        guard let product = viewModel.processScannedPayload(payload) else { return }
        if product.expirationRisk != .safe {
            liveWarning = product
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            playRiskAlert(for: product.expirationRisk)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if liveWarning?.id == product.id {
                    liveWarning = nil
                }
            }
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func playRiskAlert(for risk: ExpirationRisk) {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlaySystemSound(1057)

        if risk == .expired {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                AudioServicesPlaySystemSound(1057)
            }
        }
    }

    private func finishScan() {
        guard !isFinishing else { return }
        isFinishing = true

        Task { @MainActor in
            await viewModel.generateAIRecommendation(storeId: storeId)
            isFinishing = false
            path.append(.recommendation(storeId))
        }
    }

    private static let sampleProducts: [QRProductSample] = [
        QRProductSample(index: 1, sku: "PAN-BLANCO", name: "Pan Blanco", batch: "PB-2601", expiresAt: "2026-05-03", quantity: 1, buyPrice: 38, sellPrice: 48, riskLabel: "Caducado"),
        QRProductSample(index: 2, sku: "MEDIAS-NOCHES", name: "Medias Noches", batch: "MN-2602", expiresAt: "2026-05-08", quantity: 1, buyPrice: 42, sellPrice: 56, riskLabel: "Proximo"),
        QRProductSample(index: 3, sku: "GANSITO", name: "Gansito", batch: "GA-2509", expiresAt: "2026-04-28", quantity: 1, buyPrice: 16, sellPrice: 23, riskLabel: "Caducado"),
        QRProductSample(index: 4, sku: "TAKIS", name: "Takis", batch: "TK-2610", expiresAt: "2026-08-15", quantity: 1, buyPrice: 14, sellPrice: 22, riskLabel: "Vigente"),
        QRProductSample(index: 5, sku: "BIM-NITO-001", name: "Nito", batch: "NI-2604", expiresAt: "2026-05-12", quantity: 1, buyPrice: 14.5, sellPrice: 18, riskLabel: "Proximo"),
        QRProductSample(index: 6, sku: "PAN-BLANCO", name: "Pan Blanco", batch: "PB-2605", expiresAt: "2026-06-18", quantity: 2, buyPrice: 38, sellPrice: 48, riskLabel: "Vigente"),
        QRProductSample(index: 7, sku: "MEDIAS-NOCHES", name: "Medias Noches", batch: "MN-2508", expiresAt: "2026-04-21", quantity: 1, buyPrice: 42, sellPrice: 56, riskLabel: "Caducado"),
        QRProductSample(index: 8, sku: "GANSITO", name: "Gansito", batch: "GA-2611", expiresAt: "2026-07-05", quantity: 1, buyPrice: 16, sellPrice: 23, riskLabel: "Vigente"),
        QRProductSample(index: 9, sku: "TAKIS", name: "Takis", batch: "TK-2607", expiresAt: "2026-05-17", quantity: 1, buyPrice: 14, sellPrice: 22, riskLabel: "Proximo"),
        QRProductSample(index: 10, sku: "BIM-NITO-001", name: "Nito", batch: "NI-2506", expiresAt: "2026-04-15", quantity: 1, buyPrice: 14.5, sellPrice: 18, riskLabel: "Caducado"),
        QRProductSample(index: 11, sku: "PAN-BLANCO", name: "Pan Blanco", batch: "PB-2608", expiresAt: "2026-05-19", quantity: 3, buyPrice: 38, sellPrice: 48, riskLabel: "Proximo"),
        QRProductSample(index: 12, sku: "MEDIAS-NOCHES", name: "Medias Noches", batch: "MN-2612", expiresAt: "2026-09-01", quantity: 1, buyPrice: 42, sellPrice: 56, riskLabel: "Vigente"),
        QRProductSample(index: 13, sku: "GANSITO", name: "Gansito", batch: "GA-2606", expiresAt: "2026-05-10", quantity: 1, buyPrice: 16, sellPrice: 23, riskLabel: "Proximo"),
        QRProductSample(index: 14, sku: "TAKIS", name: "Takis", batch: "TK-2504", expiresAt: "2026-03-30", quantity: 1, buyPrice: 14, sellPrice: 22, riskLabel: "Caducado"),
        QRProductSample(index: 15, sku: "BIM-NITO-001", name: "Nito", batch: "NI-2613", expiresAt: "2026-06-20", quantity: 1, buyPrice: 14.5, sellPrice: 18, riskLabel: "Vigente"),
        QRProductSample(index: 16, sku: "PAN-BLANCO", name: "Pan Blanco", batch: "PB-2614", expiresAt: "2026-07-11", quantity: 1, buyPrice: 38, sellPrice: 48, riskLabel: "Vigente"),
        QRProductSample(index: 17, sku: "MEDIAS-NOCHES", name: "Medias Noches", batch: "MN-2603", expiresAt: "2026-05-06", quantity: 2, buyPrice: 42, sellPrice: 56, riskLabel: "Proximo"),
        QRProductSample(index: 18, sku: "GANSITO", name: "Gansito", batch: "GA-2505", expiresAt: "2026-04-05", quantity: 1, buyPrice: 16, sellPrice: 23, riskLabel: "Caducado"),
        QRProductSample(index: 19, sku: "TAKIS", name: "Takis", batch: "TK-2615", expiresAt: "2026-10-15", quantity: 2, buyPrice: 14, sellPrice: 22, riskLabel: "Vigente"),
        QRProductSample(index: 20, sku: "BIM-NITO-001", name: "Nito", batch: "NI-2609", expiresAt: "2026-05-15", quantity: 1, buyPrice: 14.5, sellPrice: 18, riskLabel: "Proximo"),
        QRProductSample(index: 21, sku: "PAN-BLANCO", name: "Pan Blanco", batch: "PB-2507", expiresAt: "2026-04-18", quantity: 1, buyPrice: 38, sellPrice: 48, riskLabel: "Caducado"),
        QRProductSample(index: 22, sku: "MEDIAS-NOCHES", name: "Medias Noches", batch: "MN-2616", expiresAt: "2026-08-03", quantity: 1, buyPrice: 42, sellPrice: 56, riskLabel: "Vigente"),
        QRProductSample(index: 23, sku: "GANSITO", name: "Gansito", batch: "GA-2617", expiresAt: "2026-06-25", quantity: 1, buyPrice: 16, sellPrice: 23, riskLabel: "Vigente"),
        QRProductSample(index: 24, sku: "TAKIS", name: "Takis", batch: "TK-2601", expiresAt: "2026-05-09", quantity: 1, buyPrice: 14, sellPrice: 22, riskLabel: "Proximo"),
        QRProductSample(index: 25, sku: "BIM-NITO-001", name: "Nito", batch: "NI-2501", expiresAt: "2026-04-01", quantity: 1, buyPrice: 14.5, sellPrice: 18, riskLabel: "Caducado")
    ]
}

private struct QRProductSample: Identifiable {
    let index: Int
    let sku: String
    let name: String
    let batch: String
    let expiresAt: String
    let quantity: Int
    let buyPrice: Double
    let sellPrice: Double
    let riskLabel: String

    var id: Int { index }

    var title: String {
        "\(index). \(name)"
    }

    var payload: String {
        """
        {"type":"product","sku":"\(sku)","name":"\(name)","batch":"\(batch)","expiresAt":"\(expiresAt)","quantity":\(quantity),"buyPrice":\(buyPrice),"sellPrice":\(sellPrice)}
        """
    }

    var riskTint: Color {
        switch riskLabel {
        case "Caducado": AppTheme.bimboRed
        case "Proximo": AppTheme.warning
        default: AppTheme.success
        }
    }
}

private struct QRTestCodeView: View {
    let sample: QRProductSample

    var body: some View {
        VStack(spacing: 8) {
            qrImage
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 132, height: 132)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(sample.title)
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(sample.riskLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(sample.riskTint)
                .background(sample.riskTint.opacity(0.14), in: Capsule())
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var qrImage: Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(sample.payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else {
            return Image(systemName: "qrcode")
        }

        let scaledImage = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return Image(systemName: "qrcode")
        }
        return Image(uiImage: UIImage(cgImage: cgImage))
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
