import SwiftUI

// MARK: - Main Recommendation View

struct ShelfRecommendationView: View {
    let result: ShelfAnalysisResult
    let storeName: String
    var onRetry: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusBanner
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

    // MARK: - Shelf Diagram (visual)

    private var shelfDiagram: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Acomodo recomendado", systemImage: "rectangle.split.3x3")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)

            VStack(spacing: 0) {
                ForEach(orderedZones) { zone in
                    ShelfZoneRow(zone: zone)
                    if zone.id != orderedZones.last?.id {
                        // Tablón separador entre niveles
                        Rectangle()
                            .fill(Color(white: 0.72))
                            .frame(height: 6)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(white: 0.75), lineWidth: 1.5)
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
        let order = ["top", "eye", "bottom"]
        return result.shelfZones.sorted {
            (order.firstIndex(of: $0.zone) ?? 99) < (order.firstIndex(of: $1.zone) ?? 99)
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
            // Header de la zona
            HStack(spacing: 6) {
                Image(systemName: zoneIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(zoneColor)
                Text(zone.label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.secondary)
                Spacer()
                recommendationChip
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Productos como tarjetas con imagen
            if zone.products.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
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
        .background(zoneColor.opacity(0.05))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(zoneColor)
                .frame(width: 4)
        }
    }

    private var zoneColor: Color {
        switch zone.recommendation {
        case "urgente": return .red
        case "reponer": return AppTheme.warning
        default:        return AppTheme.success
        }
    }

    private var zoneIcon: String {
        switch zone.zone {
        case "top":    return "arrow.up"
        case "eye":    return "eye.fill"
        case "bottom": return "arrow.down"
        default:       return "square"
        }
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
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .padding(.trailing, 10)
    }
}

// MARK: - Product Image Card

struct ProductImageCard: View {
    let product: ShelfZoneProduct

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                // Imagen del producto desde Assets
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

                    // Overlay para "retirar"
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

            // Badge de cantidad (solo si hay que reponer)
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
