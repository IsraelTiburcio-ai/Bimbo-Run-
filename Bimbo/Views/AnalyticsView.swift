import SwiftUI

struct AnalyticsView: View {
    @Bindable var viewModel: RoutePerfectaViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    kpiGrid
                    achievements
                }
                .padding(18)
            }
            .background(AppTheme.subtleGradient.ignoresSafeArea())
            .navigationTitle("Impacto")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bimbo Run", systemImage: "chart.bar.fill")
                .font(.headline.weight(.bold))
            Text("Impacto de la ruta")
                .font(.largeTitle.weight(.bold))
            Text("Resumen operativo de tiempo, merma, venta estimada y productividad.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var kpiGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                KPIStatCard(title: "Tiempo ahorrado", value: "\(viewModel.savedMinutes) min", subtitle: "acumulado", systemImage: "clock.badge.checkmark.fill", tint: AppTheme.electricBlue, progress: min(Double(viewModel.savedMinutes) / 120, 1))
                KPIStatCard(title: "Tiendas completadas", value: "\(viewModel.completedCount)", subtitle: "de \(viewModel.stores.count)", systemImage: "storefront.circle.fill", tint: AppTheme.success, progress: viewModel.routeProgress)
            }
            GridRow {
                KPIStatCard(title: "Merma evitada", value: "\(viewModel.avoidedWaste) pzs", subtitle: "producto retirado", systemImage: "leaf.circle.fill", tint: AppTheme.bimboRed, progress: min(Double(viewModel.avoidedWaste) / 30, 1))
                KPIStatCard(title: "Ventas estimadas", value: "$\(Int(viewModel.estimatedSales))", subtitle: "colocacion sugerida", systemImage: "chart.line.uptrend.xyaxis", tint: AppTheme.warning, progress: min(viewModel.estimatedSales / 6000, 1))
            }
            GridRow {
                KPIStatCard(title: "Producto retirado", value: "\(viewModel.removedProductsCount)", subtitle: "a tiempo", systemImage: "checkmark.shield.fill", tint: AppTheme.deepBlue, progress: min(Double(viewModel.removedProductsCount) / 20, 1))
                KPIStatCard(title: "Inventario restante", value: "\(viewModel.totalAvailableUnits)", subtitle: "piezas", systemImage: "box.truck.fill", tint: AppTheme.success, progress: min(Double(viewModel.totalAvailableUnits) / 100, 1))
            }
        }
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Logros")
                .font(.title3.weight(.bold))
            achievement("Productividad", progress: min(Double(viewModel.savedMinutes) / 90, 1), icon: "bolt.fill")
            achievement("Merma cero", progress: min(Double(viewModel.avoidedWaste) / 24, 1), icon: "leaf.fill")
            achievement("Ruta eficiente", progress: viewModel.routeProgress, icon: "map.fill")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func achievement(_ title: String, progress: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.deepBlue)
            }
            ProgressView(value: progress)
                .tint(AppTheme.bimboRed)
        }
    }
}
