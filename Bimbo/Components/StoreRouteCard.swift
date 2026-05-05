import SwiftUI

struct StoreRouteCard: View {
    var store: Store
    var stop: RouteStop

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Text("\(stop.order)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(store.status.tint, in: Circle())

                Rectangle()
                    .fill(store.status.tint.opacity(0.25))
                    .frame(width: 3, height: 34)
                    .clipShape(Capsule())
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    StatusBadge(status: store.status)
                }

                Text("\(stop.eta) - \(stop.distance) - \(store.address)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(stop.routeNote, systemImage: "sparkles")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
