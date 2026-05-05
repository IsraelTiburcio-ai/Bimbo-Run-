import SwiftUI

struct StoreDetailView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID
    @Binding var path: [AppRoute]

    private var store: Store? {
        viewModel.store(for: storeId)
    }

    var body: some View {
        ScrollView {
            if let store {
                VStack(alignment: .leading, spacing: 18) {
                    hero(store)
                    detailGrid(store)
                    productHistory(store)
                    visitHistory(store)
                    PrimaryButton(title: "Escanear anaquel", systemImage: "viewfinder") {
                        viewModel.startVisit(storeId: store.id)
                        path.append(.scan(store.id))
                    }
                }
                .padding(18)
            } else {
                ContentUnavailableView("Tienda no encontrada", systemImage: "exclamationmark.triangle")
            }
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle(store?.name ?? "Detalle")
    }

    private func hero(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.name)
                        .font(.title.weight(.bold))
                    Text("\(store.clientId) - \(store.type.rawValue)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
                Spacer()
                StatusBadge(status: store.status)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            Label(store.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))

            Text("Presupuesto estimado: $\(Int(store.estimatedBudget))")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func detailGrid(_ store: Store) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                infoCard("Mas vendido", store.bestSellers.joined(separator: ", "), "star.fill", AppTheme.warning)
                infoCard("Baja rotacion", store.lowRotationProducts.joined(separator: ", "), "arrow.down.forward.circle.fill", AppTheme.bimboRed)
            }
            GridRow {
                infoCard("Ultima visita", store.lastVisit, "clock.fill", AppTheme.electricBlue)
                infoCard("Devolucion", store.lastReturn, "arrow.uturn.backward.circle.fill", AppTheme.success)
            }
        }
    }

    private func infoCard(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(3)
                .minimumScaleFactor(0.74)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func productHistory(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ultimos productos dejados", systemImage: "shippingbox.fill")
                .font(.headline.weight(.bold))
            ForEach(store.lastDeliveredProducts) { item in
                HStack {
                    Text(item.product.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(item.quantity) pzs")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.deepBlue)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func visitHistory(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Historial", systemImage: "clock.arrow.circlepath")
                .font(.headline.weight(.bold))
            ForEach(store.visitHistory, id: \.self) { event in
                Label(event, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
