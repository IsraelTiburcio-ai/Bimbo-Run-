import SwiftUI

// MARK: - Main View

struct ShelfRecommendationView: View {
    let result: ShelfAnalysisResult
    let storeName: String
    var onRetry: (() -> Void)?

    private var voice: VoiceService { VoiceService.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusBanner
                voiceCard
                shelfDiagram
                restockBadge
                if let retry = onRetry {
                    Button { retry() } label: {
                        Label("Nueva foto", systemImage: "camera.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.deepBlue)
                    .padding(.bottom, 4)
                }
            }
            .padding(18)
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: statusIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(statusColor)
                Text(storeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(result.overallStatus.uppercased())
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(statusColor.opacity(0.14), in: Capsule())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Voice Card

    private var voiceCard: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Escuchar recomendaciones", systemImage: "ear.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.deepBlue)
                Spacer()
                VoiceToggleRow()
            }
            if let summary = result.voiceSummary {
                VoicePlayButton(text: summary, label: "Escuchar recomendaciones")
            } else {
                Text("Resumen de voz no disponible")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Shelf Diagram (visual, niveles dinámicos)

    private var shelfDiagram: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Acomodo recomendado", systemImage: "rectangle.split.3x3")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.deepBlue)
                Spacer()
                // Contador de niveles
                let newCount = result.shelfZones.filter { $0.isNewLevel == true }.count
                if newCount > 0 {
                    Label("+\(newCount) nivel\(newCount > 1 ? "es" : "")", systemImage: "plus.rectangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.success)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(orderedZones.enumerated()), id: \.element.id) { index, zone in
                    ShelfZoneRow(zone: zone)
                    if index < orderedZones.count - 1 {
                        // Tablón separador entre niveles
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.60), Color(white: 0.78), Color(white: 0.60)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(height: 7)
                            .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(white: 0.72), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Restock Badge

    private var restockBadge: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(AppTheme.deepBlue)
            Text("Piezas a reponer")
                .font(.subheadline)
            Spacer()
            Text("\(result.estimatedRestock) pzs")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.bimboRed)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private var orderedZones: [ShelfZone] {
        // Niveles a quitar al final, nuevos al final también
        result.shelfZones.sorted {
            let removeA = $0.shouldRemove == true ? 1 : 0
            let removeB = $1.shouldRemove == true ? 1 : 0
            if removeA != removeB { return removeA < removeB }
            return $0.zone < $1.zone
        }
    }

    private var statusColor: Color {
        switch result.overallStatus {
        case "critico":  return .red
        case "atencion": return AppTheme.warning
        default:         return AppTheme.success
        }
    }

    private var statusIcon: String {
        switch result.overallStatus {
        case "critico":  return "exclamationmark.triangle.fill"
        case "atencion": return "exclamationmark.circle.fill"
        default:         return "checkmark.circle.fill"
        }
    }

    private var statusTitle: String {
        switch result.overallStatus {
        case "critico":  return "Anaquel crítico"
        case "atencion": return "Requiere atención"
        default:         return "Anaquel en buen estado"
        }
    }
}

// MARK: - Zone Row

struct ShelfZoneRow: View {
    let zone: ShelfZone

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(zoneColor)
                Text(zone.label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.secondary)
                Spacer()
                levelBadges
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Productos
            if zone.shouldRemove == true {
                HStack {
                    Image(systemName: "trash.fill").foregroundStyle(.red)
                    Text("Quitar este nivel")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else if zone.products.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
                    Text("Nivel completo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(zone.products) { product in
                            ProductImageCard(product: product)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(backgroundStyle)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(zoneColor)
                .frame(width: 4)
        }
        // Borde superior punteado si es nivel nuevo
        .overlay(alignment: .top) {
            if zone.isNewLevel == true {
                Rectangle()
                    .stroke(AppTheme.success, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(height: 2)
            }
        }
    }

    @ViewBuilder
    private var levelBadges: some View {
        HStack(spacing: 4) {
            if zone.isNewLevel == true {
                Text("+ NUEVO NIVEL")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(AppTheme.success.opacity(0.14), in: Capsule())
            }
            if zone.shouldRemove == true {
                Text("QUITAR")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.red.opacity(0.14), in: Capsule())
            }
            recommendationChip
        }
        .padding(.trailing, 10)
    }

    private var recommendationChip: some View {
        let (label, color): (String, Color) = {
            switch zone.recommendation {
            case "urgente": return ("URGENTE", .red)
            case "reponer": return ("REPONER", AppTheme.warning)
            default:        return ("OK ✓", AppTheme.success)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var zoneColor: Color {
        if zone.isNewLevel == true { return AppTheme.success }
        if zone.shouldRemove == true { return .red }
        switch zone.recommendation {
        case "urgente": return .red
        case "reponer": return AppTheme.warning
        default:        return AppTheme.success
        }
    }

    private var backgroundStyle: Color {
        if zone.isNewLevel == true { return AppTheme.success.opacity(0.04) }
        if zone.shouldRemove == true { return Color.red.opacity(0.04) }
        return zoneColor.opacity(0.05)
    }
}

// MARK: - Product Image Card

struct ProductImageCard: View {
    let product: ShelfZoneProduct

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.96))
                        .frame(width: 78, height: 78)

                    if UIImage(named: product.imageName) != nil {
                        Image(product.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(actionColor.opacity(0.5))
                    }

                    // Overlay retirar
                    if product.action == "retirar" {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.35))
                            .frame(width: 78, height: 78)
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(actionColor.opacity(0.5), lineWidth: 2)
                )

                Text(product.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 78)
            }

            // Badge cantidad
            if product.qty > 0 && product.action != "ok" {
                ZStack {
                    Circle()
                        .fill(actionColor)
                        .frame(width: 24, height: 24)
                    Text("+\(product.qty)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    private var actionColor: Color {
        switch product.action {
        case "retirar": return .red
        case "reponer": return AppTheme.warning
        default:        return AppTheme.success
        }
    }
}

// MARK: - Preview

#Preview {
    let mock = ShelfAnalysisService().mockResult()
    ShelfRecommendationView(result: mock, storeName: "Abarrotes Lupita")
}
