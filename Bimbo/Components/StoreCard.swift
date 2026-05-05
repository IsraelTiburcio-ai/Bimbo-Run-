import SwiftUI

struct StoreCard: View {
    var store: Store

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.subtleGradient)

                Image(systemName: store.status == .completed ? "checkmark.seal.fill" : "storefront.fill")
                    .foregroundStyle(store.status.tint)
                    .font(.title3)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    StatusBadge(status: store.status)
                }

                Text("\(store.clientId) - \(store.address)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.bimboRed)
                    Text(store.aiHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.bimboRed.opacity(0.08), in: Capsule())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
