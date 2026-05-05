import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: RoutePerfectaViewModel

    var body: some View {
        RouteView(viewModel: viewModel)
    }
}
