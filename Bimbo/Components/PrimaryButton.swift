import SwiftUI

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 18)
            .foregroundStyle(.white)
            .background(AppTheme.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.deepBlue.opacity(0.24), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
