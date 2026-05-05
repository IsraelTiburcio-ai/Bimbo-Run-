import SwiftUI

struct StatusBadge: View {
    var status: StoreStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(status.tint)
            .background(status.tint.opacity(0.14), in: Capsule())
            .accessibilityLabel("Estado \(status.title)")
    }
}
