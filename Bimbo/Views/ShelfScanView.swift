import SwiftUI

struct ShelfScanView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    var body: some View {
        ScanView(viewModel: viewModel, storeId: storeId, path: $path)
    }
}
