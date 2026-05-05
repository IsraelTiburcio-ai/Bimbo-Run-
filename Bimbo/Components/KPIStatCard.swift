import SwiftUI

struct KPIStatCard: View {
    var title: String
    var value: String
    var subtitle: String
    var systemImage: String
    var tint: Color = AppTheme.electricBlue
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer()
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.78)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progress {
                ProgressView(value: progress)
                    .tint(tint)
                    .accessibilityValue("\(Int(progress * 100)) por ciento")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}
