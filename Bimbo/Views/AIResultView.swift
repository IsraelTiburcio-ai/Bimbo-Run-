import SwiftUI

struct AIResultView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    var body: some View {
        AIRecommendationView(viewModel: viewModel, storeId: storeId, path: $path)
    }
}
