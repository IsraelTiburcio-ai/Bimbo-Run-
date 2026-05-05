import SwiftUI

struct StoreListView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @State private var path: [AppRoute] = []
    @State private var query = ""

    private var filteredStores: [Store] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return viewModel.stores }
        return viewModel.stores.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.clientId.localizedCaseInsensitiveContains(query) ||
            $0.address.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(filteredStores) { store in
                        Button {
                            path.append(.storeDetail(store.id))
                        } label: {
                            StoreCard(store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(AppTheme.subtleGradient.ignoresSafeArea())
            .navigationTitle("Tiendas")
            .searchable(text: $query, prompt: "Buscar tienda o cliente")
            .toolbar {
                ToolbarItem {
                    Button {
                        path.append(.addStore)
                    } label: {
                        Label("Agregar tienda", systemImage: "plus.circle.fill")
                    }
                    .foregroundStyle(AppTheme.bimboRed)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tiendas")
                .font(.largeTitle.weight(.bold))
            Text("Historial, prioridad y recomendaciones por punto de venta.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .addStore:
            AddStoreView(viewModel: viewModel, path: $path)
        case .storeDetail(let storeId):
            StoreDetailView(viewModel: viewModel, storeId: storeId, path: $path)
        case .scan(let storeId):
            ScanView(viewModel: viewModel, storeId: storeId, path: $path)
        case .recommendation(let storeId):
            AIRecommendationView(viewModel: viewModel, storeId: storeId, path: $path)
        case .finalOrder(let storeId):
            FinalOrderView(viewModel: viewModel, storeId: storeId, path: $path)
        }
    }
}
