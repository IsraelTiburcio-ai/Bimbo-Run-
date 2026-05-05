import SwiftUI

struct FinalOrderView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Binding var path: [AppRoute]

    @State private var orderItems: [OrderItem]
    @State private var notes = ""
    @State private var didConfirm = false

    init(viewModel: RoutePerfectaViewModel, storeId: UUID?, path: Binding<[AppRoute]>) {
        self.viewModel = viewModel
        self.storeId = storeId
        self._path = path
        let result = viewModel.latestScanResult ?? viewModel.mockScanResult(storeId: storeId)
        self._orderItems = State(initialValue: viewModel.buildOrder(from: result))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                inventoryWarning

                VStack(spacing: 12) {
                    ForEach($orderItems) { $item in
                        orderRow(item: $item)
                    }
                }

                notesCard

                if didConfirm {
                    confirmationCard
                }

                PrimaryButton(title: didConfirm ? "Volver a Ruta" : "Confirmar pedido", systemImage: didConfirm ? "map.fill" : "checkmark.seal.fill") {
                    if didConfirm {
                        path.removeAll()
                    } else {
                        confirmOrder()
                    }
                }
            }
            .padding(18)
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle("Pedido final")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.store(for: storeId)?.name ?? "Pedido rapido")
                .font(.title.weight(.bold))
            Text("Ajusta cantidades antes de confirmar. El inventario del camion se actualiza al guardar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inventoryWarning: some View {
        let warnings = viewModel.inventoryAvailability(for: orderItems)
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Revisa inventario antes de confirmar", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.bimboRed)
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(AppTheme.bimboRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func orderRow(item: Binding<OrderItem>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.wrappedValue.product.symbolName)
                .foregroundStyle(item.wrappedValue.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed)
                .frame(width: 38, height: 38)
                .background((item.wrappedValue.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed).opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.wrappedValue.product.name)
                    .font(.headline.weight(.semibold))
                Text("\(item.wrappedValue.action.rawValue) - disponible \(item.wrappedValue.availableInTruck)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(value: item.quantity, in: 0...99) {
                Text("\(item.wrappedValue.quantity)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 34)
                    .foregroundStyle(AppTheme.deepBlue)
            }
            .labelsHidden()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notas del pedido", systemImage: "note.text")
                .font(.headline.weight(.bold))
            TextEditor(text: $notes)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(AppTheme.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var confirmationCard: some View {
        Label(viewModel.lastConfirmationMessage ?? "Pedido confirmado.", systemImage: "checkmark.circle.fill")
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.success)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func confirmOrder() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            didConfirm = true
        }
        viewModel.confirmOrder(storeId: storeId, items: orderItems, notes: notes)
    }
}
