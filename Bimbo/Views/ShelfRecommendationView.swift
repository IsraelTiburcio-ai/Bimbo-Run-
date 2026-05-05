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
                actionsCard
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
            Text(statusBadge)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(statusColor.opacity(0.14), in: Capsule())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Shelf Diagram

    private var shelfDiagram: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Anaquel", systemImage: "rectangle.split.3x3")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)

            VStack(spacing: 2) {
                ForEach(orderedZones) { zone in
                    ShelfZoneRow(zone: zone)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(white: 0.8), lineWidth: 1)
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Acciones prioritarias", systemImage: "bolt.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)

            ForEach(result.topActions) { action in
                ShelfActionRow(action: action)
                if action.id != result.topActions.last?.id {
                    Divider()
                }
            }
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

    private var statusBadge: String {
        result.overallStatus.uppercased()
    }
}

// MARK: - Zone Row

struct ShelfZoneRow: View {
    let zone: ShelfZone

    var body: some View {
        HStack(spacing: 0) {
            // Barra lateral de color
            Rectangle()
                .fill(zoneColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 8) {
                // Header de la zona
                HStack {
                    Image(systemName: zoneIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(zoneColor)
                    Text(zone.label.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.secondary)
                    Spacer()
                    recommendationChip
                }

                // Chips de productos
                if zone.products.isEmpty {
                    Text("Sin cambios")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(zone.products) { product in
                            ProductChip(product: product)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(zoneColor.opacity(0.06))
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
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Product Chip

struct ProductChip: View {
    let product: ShelfZoneProduct

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: actionIcon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(actionColor)
            Text(shortName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            if product.qty > 0 {
                Text("\(product.qty)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(actionColor, in: Capsule())
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(actionColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var shortName: String {
        product.name.split(separator: " ").prefix(2).joined(separator: " ")
    }

    private var actionColor: Color {
        switch product.action {
        case "retirar": return .red
        case "reponer": return AppTheme.warning
        default:        return AppTheme.success
        }
    }

    private var actionIcon: String {
        switch product.action {
        case "retirar": return "xmark"
        case "reponer": return "plus"
        default:        return "checkmark"
        }
    }
}

// MARK: - Action Row

struct ShelfActionRow: View {
    let action: ShelfTopAction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(priorityColor)
                .frame(width: 36, height: 36)
                .background(priorityColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(action.text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Spacer()

            Text(action.priority.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(priorityColor.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch action.priority {
        case "alta":  return .red
        case "media": return AppTheme.warning
        default:      return AppTheme.success
        }
    }

    private var typeIcon: String {
        switch action.type {
        case "subir":   return "arrow.up.circle.fill"
        case "reponer": return "shippingbox.fill"
        case "retirar": return "trash.fill"
        default:        return "eye.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    let mock = ShelfAnalysisResult(
        overallStatus: "atencion",
        shelfZones: [
            ShelfZone(zone: "top", label: "Nivel alto", recommendation: "ok",
                      products: [ShelfZoneProduct(name: "Pan Blanco", action: "ok", qty: 0, sku: "PAN-BLANCO")]),
            ShelfZone(zone: "eye", label: "Nivel vista", recommendation: "urgente",
                      products: [
                        ShelfZoneProduct(name: "Medias Noches", action: "reponer", qty: 8, sku: "MEDIAS-NOCHES"),
                        ShelfZoneProduct(name: "Gansito", action: "retirar", qty: 2, sku: "GANSITO")
                      ]),
            ShelfZone(zone: "bottom", label: "Nivel bajo", recommendation: "reponer",
                      products: [ShelfZoneProduct(name: "Takis", action: "reponer", qty: 6, sku: "TAKIS")])
        ],
        topActions: [
            ShelfTopAction(type: "reponer", text: "Surtir Medias Noches nivel vista", priority: "alta"),
            ShelfTopAction(type: "retirar", text: "Retirar Gansito caducado", priority: "alta"),
            ShelfTopAction(type: "subir", text: "Subir Takis a nivel mano", priority: "media")
        ],
        estimatedRestock: 16
    )
    ShelfRecommendationView(result: mock, storeName: "Abarrotes Lupita")
}
