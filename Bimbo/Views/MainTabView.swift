import SwiftUI

enum MainTab: Hashable {
    case truck
    case route
    case stores
    case impact
}

struct MainTabView: View {
    @State private var viewModel = RoutePerfectaViewModel()
    @State private var selectedTab: MainTab = .route

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TruckInventoryView(viewModel: viewModel)
            }
                .tabItem {
                    Label("Camión", systemImage: "box.truck.fill")
                }
                .tag(MainTab.truck)

            RouteView(viewModel: viewModel)
                .tabItem {
                    Label("Ruta", systemImage: "map.fill")
                }
                .tag(MainTab.route)

            StoreListView(viewModel: viewModel)
                .tabItem {
                    Label("Tiendas", systemImage: "storefront.fill")
                }
                .tag(MainTab.stores)

            AnalyticsView(viewModel: viewModel)
                .tabItem {
                    Label("Impacto", systemImage: "chart.bar.fill")
                }
                .tag(MainTab.impact)
        }
        .tint(AppTheme.bimboRed)
    }
}
