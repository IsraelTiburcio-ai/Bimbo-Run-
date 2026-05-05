import SwiftUI

struct RouteView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    mockMapCard
                    nextStoreCard
                    inventoryStrip
                    routeStopsList
                }
                .padding(18)
            }
            .background(pageBackground)
            .navigationTitle("Ruta")
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
    }

    private var pageBackground: some View {
        ZStack {
            AppTheme.systemBackground
            AppTheme.subtleGradient.ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bimbo Run")
                .font(.largeTitle.weight(.bold))
            Text("Copiloto de ruta del dia")
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressView(value: viewModel.routeProgress)
                .tint(AppTheme.bimboRed)
                .accessibilityLabel("Progreso de ruta")
            Text("\(viewModel.completedCount) de \(viewModel.routeStops.count) tiendas completadas")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var mockMapCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.brandGradient)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Deposito Norte", systemImage: "building.2.fill")
                    Spacer()
                    Label("Regreso", systemImage: "arrow.uturn.backward")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.86))

                HStack(spacing: 12) {
                    routeDot("1", active: true)
                    routeLine
                    routeDot("2", active: false)
                    routeLine
                    routeDot("3", active: false)
                }

                Text("Ruta optimizada por tiempo: evita zona de trafico y cierra de regreso al deposito.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))

                Button {
                    viewModel.openMapsMock()
                } label: {
                    Label("Abrir en Maps/Waze", systemImage: "location.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .foregroundStyle(AppTheme.deepBlue)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if let message = viewModel.mapsStatusMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
            .padding(18)
        }
        .frame(minHeight: 240)
    }

    private var routeLine: some View {
        Rectangle()
            .fill(.white.opacity(0.42))
            .frame(height: 4)
            .clipShape(Capsule())
    }

    private func routeDot(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.headline.weight(.bold))
            .foregroundStyle(active ? AppTheme.bimboRed : AppTheme.deepBlue)
            .frame(width: 44, height: 44)
            .background(.white, in: Circle())
    }

    @ViewBuilder
    private var nextStoreCard: some View {
        if let store = viewModel.nextStore {
            VStack(alignment: .leading, spacing: 12) {
                Label("Siguiente tienda", systemImage: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.deepBlue)
                Text(store.name)
                    .font(.title2.weight(.bold))
                Text(store.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                PrimaryButton(title: "Entrar a tienda", systemImage: "figure.walk.arrival") {
                    viewModel.startVisit(storeId: store.id)
                    path.append(.storeDetail(store.id))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var inventoryStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventario resumido")
                .font(.title3.weight(.bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.truckInventory.prefix(4)) { item in
                        InventoryMiniCard(item: item, compact: true)
                            .frame(width: 190)
                    }
                }
            }
        }
    }

    private var routeStopsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paradas")
                .font(.title3.weight(.bold))

            ForEach(viewModel.routeStops.sorted { $0.order < $1.order }) { stop in
                if let store = viewModel.store(for: stop.storeId) {
                    Button {
                        path.append(.storeDetail(store.id))
                    } label: {
                        StoreRouteCard(store: store, stop: stop)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .storeDetail(let storeId):
            StoreDetailView(viewModel: viewModel, storeId: storeId, path: $path)
        case .scan(let storeId):
            ScanView(viewModel: viewModel, storeId: storeId, path: $path)
        case .recommendation(let storeId):
            AIRecommendationView(viewModel: viewModel, storeId: storeId, path: $path)
        case .finalOrder(let storeId):
            FinalOrderView(viewModel: viewModel, storeId: storeId, path: $path)
        case .addStore:
            AddStoreView(viewModel: viewModel, path: $path)
        }
    }
}
