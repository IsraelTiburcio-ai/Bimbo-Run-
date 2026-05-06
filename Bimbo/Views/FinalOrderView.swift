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

                orderTotalCard
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
        let color = item.wrappedValue.hasEnoughInventory ? AppTheme.deepBlue : AppTheme.bimboRed
        let subtotal = Double(item.wrappedValue.quantity) * item.wrappedValue.product.salePrice

        return VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: item.wrappedValue.product.symbolName)
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.wrappedValue.product.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.wrappedValue.action.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("disp. \(item.wrappedValue.availableInTruck)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("$\(String(format: "%.2f", item.wrappedValue.product.salePrice)) c/u")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.deepBlue)
                }

                Spacer()

                // Stepper custom con número grande
                HStack(spacing: 2) {
                    Button {
                        if item.wrappedValue.quantity > 0 { item.quantity.wrappedValue -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.deepBlue)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.deepBlue.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("\(item.wrappedValue.quantity)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 52)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.deepBlue)

                    Button {
                        if item.wrappedValue.quantity < 99 { item.quantity.wrappedValue += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.deepBlue,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Subtotal por producto
            if item.wrappedValue.quantity > 0 {
                HStack {
                    Spacer()
                    Text("\(item.wrappedValue.quantity) × $\(String(format: "%.2f", item.wrappedValue.product.salePrice))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("= $\(String(format: "%.2f", subtotal))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.deepBlue)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var orderTotalCard: some View {
        let total = orderItems.reduce(0.0) { $0 + Double($1.quantity) * $1.product.salePrice }
        let units = orderItems.reduce(0) { $0 + $1.quantity }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total del pedido")
                    .font(.headline.weight(.bold))
                Text("\(units) piezas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("$\(String(format: "%.2f", total))")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.deepBlue)
        }
        .padding(16)
        .background(AppTheme.deepBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppTheme.deepBlue.opacity(0.2), lineWidth: 1.5))
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
