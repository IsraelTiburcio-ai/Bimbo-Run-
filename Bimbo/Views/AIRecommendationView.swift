import SwiftUI

struct AIRecommendationView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    private var result: ScanResult {
        viewModel.latestScanResult ?? viewModel.mockScanResult(storeId: storeId)
    }

    private var isAIResult: Bool {
        viewModel.latestScanResult != nil && viewModel.aiErrorMessage == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let errorMsg = viewModel.aiErrorMessage {
                    aiErrorBanner(errorMsg)
                }
                if !result.inventoryAlerts.isEmpty {
                    alertCard
                }
                section("Productos a retirar", icon: "exclamationmark.triangle.fill", tint: AppTheme.bimboRed, items: result.productsToRemove)
                section("Productos a reponer", icon: "shippingbox.fill", tint: AppTheme.electricBlue, items: result.productsToReplenish)
                section("Sugeridos por inventario", icon: "sparkles", tint: AppTheme.success, items: result.suggestedProducts)
                layoutCard
                actionButtons
            }
            .padding(18)
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle("Recomendacion IA")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isAIResult ? "Bimbo Run IA · Groq" : "Bimbo Run IA", systemImage: "sparkles")
                .font(.headline.weight(.bold))
            Text(viewModel.store(for: storeId)?.name ?? "Escaneo rapido")
                .font(.title.weight(.bold))
            Text(isAIResult
                 ? "Recomendacion generada por IA con contexto real de la tienda e inventario."
                 : "Recomendacion basada en historial, presupuesto e inventario disponible.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func aiErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(AppTheme.warning)
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var alertCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Inventario insuficiente", systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.bimboRed)
            ForEach(result.inventoryAlerts, id: \.self) { alert in
                Text(alert)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppTheme.bimboRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func section(_ title: String, icon: String, tint: Color, items: [OrderItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            ForEach(items) { item in
                orderPreviewRow(item)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func orderPreviewRow(_ item: OrderItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.product.symbolName)
                .foregroundStyle(item.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed)
                .frame(width: 32, height: 32)
                .background((item.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed).opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.name)
                    .font(.headline.weight(.semibold))
                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(item.quantity) pzs")
                .font(.headline.weight(.bold))
                .foregroundStyle(item.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed)
        }
    }

    private var layoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Acomodo sugerido", systemImage: "square.grid.3x3.fill")
                .font(.headline.weight(.bold))
            ForEach(result.layoutSuggestions, id: \.self) { suggestion in
                Label(suggestion, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Aceptar recomendacion", systemImage: "checkmark.circle.fill") {
                path.append(.finalOrder(storeId))
            }
            Button {
                path.append(.finalOrder(storeId))
            } label: {
                Label("Ajustar manualmente", systemImage: "slider.horizontal.3")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .foregroundStyle(AppTheme.deepBlue)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
