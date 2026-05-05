import SwiftUI

struct AnalyticsView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @State private var scope: AnalyticsScope = .day

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scopePicker
                    kpiGrid
                    qrRiskSummary
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
            Text(scope == .day ? "Resumen operativo del dia: ruta, escaneo, merma y venta estimada." : "Lectura semanal para operacion, logistica, ventas y bonos.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var scopePicker: some View {
        Picker("Periodo", selection: $scope) {
            ForEach(AnalyticsScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var kpiGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                KPIStatCard(title: "Tiempo ahorrado", value: "\(scaled(viewModel.savedMinutes)) min", subtitle: scope.subtitle, systemImage: "clock.badge.checkmark.fill", tint: AppTheme.electricBlue, progress: min(Double(scaled(viewModel.savedMinutes)) / 420, 1))
                KPIStatCard(title: "Tiendas completadas", value: "\(scaled(viewModel.completedCount))", subtitle: scope == .day ? "de \(viewModel.stores.count)" : "visitas semana", systemImage: "storefront.circle.fill", tint: AppTheme.success, progress: viewModel.routeProgress)
            }
            GridRow {
                KPIStatCard(title: "Merma evitada", value: "\(scaled(viewModel.avoidedWaste)) pzs", subtitle: "producto retirado", systemImage: "leaf.circle.fill", tint: AppTheme.bimboRed, progress: min(Double(scaled(viewModel.avoidedWaste)) / 90, 1))
                KPIStatCard(title: "Ventas estimadas", value: "$\(Int(scaledDouble(viewModel.estimatedSales)))", subtitle: "colocacion sugerida", systemImage: "chart.line.uptrend.xyaxis", tint: AppTheme.warning, progress: min(scaledDouble(viewModel.estimatedSales) / 22000, 1))
            }
            GridRow {
                KPIStatCard(title: "Producto retirado", value: "\(scaled(viewModel.removedProductsCount))", subtitle: "a tiempo", systemImage: "checkmark.shield.fill", tint: AppTheme.deepBlue, progress: min(Double(scaled(viewModel.removedProductsCount)) / 80, 1))
                KPIStatCard(title: "Inventario restante", value: "\(viewModel.totalAvailableUnits)", subtitle: "piezas", systemImage: "box.truck.fill", tint: AppTheme.success, progress: min(Double(viewModel.totalAvailableUnits) / 100, 1))
            }
        }
    }

    private var qrRiskSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analisis QR y caducidad", systemImage: "qrcode.viewfinder")
                .font(.title3.weight(.bold))

            HStack(spacing: 10) {
                riskChip("Escaneados", "\(scaled(max(viewModel.scannedProducts.count, 6)))", AppTheme.deepBlue)
                riskChip("Caducados", "\(scaled(max(viewModel.scannedProducts.filter { $0.expirationRisk == .expired }.count, 1)))", AppTheme.bimboRed)
                riskChip("Proximos", "\(scaled(max(viewModel.scannedProducts.filter { $0.expirationRisk == .nearExpiration }.count, 2)))", AppTheme.warning)
            }

            Text("La IA acompana al vendedor: reduce revision manual, prioriza retiros por lote y convierte el escaneo en recomendacion de pedido.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func riskChip(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func scaled(_ value: Int) -> Int {
        scope == .day ? value : value * 5
    }

    private func scaledDouble(_ value: Double) -> Double {
        scope == .day ? value : value * 5
    }
}

private enum AnalyticsScope: String, CaseIterable, Identifiable {
    case day
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Dia"
        case .week: "Semana"
        }
    }

    var subtitle: String {
        switch self {
        case .day: "hoy"
        case .week: "semana"
        }
    }
}
