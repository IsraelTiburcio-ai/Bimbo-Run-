import SwiftUI

struct TruckInventoryView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @State private var didScanTicket = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scanTicketButton
                    summaryGrid
                    inventorySection
                    lowStockSection
                    pendingStoresSummary
                }
                .padding(18)
            }
            .background(pageBackground)
            .navigationTitle("Camión")
        }
    }

    private var pageBackground: some View {
        ZStack {
            AppTheme.systemBackground
            AppTheme.subtleGradient.ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bimbo Run", systemImage: "box.truck.fill")
                .font(.headline.weight(.bold))
            Text("Inventario del camion")
                .font(.largeTitle.weight(.bold))
                .minimumScaleFactor(0.75)
            Text("Control rapido de producto disponible, sugerido y retirado durante la ruta.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var scanTicketButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            PrimaryButton(title: didScanTicket ? "Ticket mock cargado" : "Escanear ticket de carga", systemImage: "doc.viewfinder") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    didScanTicket = true
                }
            }

            if didScanTicket {
                Label("OCR real pendiente. Inventario mock confirmado para demo.", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.success)
            }
        }
    }

    private var summaryGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                KPIStatCard(title: "Disponibles", value: "\(viewModel.totalAvailableUnits)", subtitle: "piezas en camion", systemImage: "shippingbox.fill", tint: AppTheme.success)
                KPIStatCard(title: "Sugeridos", value: "\(viewModel.totalReservedSuggested)", subtitle: "para tiendas pendientes", systemImage: "sparkles", tint: AppTheme.electricBlue)
            }
            GridRow {
                KPIStatCard(title: "Retirados", value: "\(viewModel.totalReturnedUnits)", subtitle: "devoluciones", systemImage: "arrow.uturn.backward.circle.fill", tint: AppTheme.bimboRed)
                KPIStatCard(title: "Alertas", value: "\(viewModel.lowInventoryItems.count)", subtitle: "bajo inventario", systemImage: "exclamationmark.triangle.fill", tint: AppTheme.warning)
            }
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventario actual")
                .font(.title3.weight(.bold))

            ForEach(viewModel.truckInventory) { item in
                InventoryMiniCard(item: item)
            }
        }
    }

    @ViewBuilder
    private var lowStockSection: some View {
        if !viewModel.lowInventoryItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Alertas de bajo inventario", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.bimboRed)

                ForEach(viewModel.lowInventoryItems) { item in
                    Text("\(item.product.name): quedan \(item.available) piezas, umbral \(item.lowStockThreshold).")
                        .font(.subheadline.weight(.medium))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.bimboRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var pendingStoresSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resumen para tiendas pendientes", systemImage: "map.fill")
                .font(.headline.weight(.bold))
            Text("Faltan \(viewModel.pendingCount) tiendas. Hay \(viewModel.totalAvailableUnits) piezas disponibles y \(viewModel.totalReservedSuggested) piezas sugeridas por historial.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
