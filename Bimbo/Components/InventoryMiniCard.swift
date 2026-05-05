import SwiftUI

struct InventoryMiniCard: View {
    var item: TruckInventoryItem
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: item.product.symbolName)
                    .font(.headline)
                    .foregroundStyle(item.isLowStock ? AppTheme.bimboRed : AppTheme.deepBlue)
                    .frame(width: 34, height: 34)
                    .background((item.isLowStock ? AppTheme.bimboRed : AppTheme.deepBlue).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.product.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.product.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                inventoryMetric("Disp.", item.available, AppTheme.success)
                Spacer()
                inventoryMetric("Sug.", item.reservedSuggested, AppTheme.electricBlue)
                Spacer()
                inventoryMetric("Dev.", item.returned, AppTheme.bimboRed)
            }

            if item.isLowStock && !compact {
                Label("Bajo inventario", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.bimboRed)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.isLowStock ? AppTheme.bimboRed.opacity(0.35) : .white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func inventoryMetric(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
