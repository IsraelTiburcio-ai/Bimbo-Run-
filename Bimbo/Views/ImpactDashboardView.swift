import SwiftUI

struct ImpactDashboardView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @Binding var path: [AppRoute]

    var body: some View {
        AnalyticsView(viewModel: viewModel)
    }
}
