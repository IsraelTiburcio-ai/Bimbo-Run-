import SwiftUI

struct LevantarPedidoView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var quantities:  [String: Int] = [:]   // sku → qty
    @State private var searchText   = ""
    @State private var didConfirm   = false
    @State private var notes        = ""

    // Filtro de categorías
    private var categories: [String] {
        let all = viewModel.truckInventory.map(\.product.category)
        return Array(Set(all)).sorted()
    }
    @State private var selectedCategory: String? = nil

    // MARK: - Computadas

    private var filtered: [TruckInventoryItem] {
        viewModel.truckInventory.filter { item in
            let matchSearch = searchText.isEmpty ||
                item.product.name.localizedCaseInsensitiveContains(searchText) ||
                item.product.category.localizedCaseInsensitiveContains(searchText)
            let matchCat = selectedCategory == nil || item.product.category == selectedCategory
            return matchSearch && matchCat
        }
    }

    private var orderItems: [OrderItem] {
        quantities.compactMap { sku, qty in
            guard qty > 0,
                  let item = viewModel.truckInventory.first(where: { $0.product.sku == sku }) else { return nil }
            return OrderItem(product: item.product, quantity: qty, action: .replenish,
                             note: "", availableInTruck: item.available)
        }
        .sorted { $0.product.name < $1.product.name }
    }

    private var totalAmount: Double { orderItems.reduce(0) { $0 + Double($1.quantity) * $1.product.salePrice } }
    private var totalUnits:  Int    { orderItems.reduce(0) { $0 + $1.quantity } }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Total sticky ──────────────────────────────
                totalBar

                // ── Lista de productos ────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        // Filtros de categoría
                        Section {
                            EmptyView()
                        } header: {
                            categoryFilter
                        }

                        // Resumen de selección (si hay items)
                        if !orderItems.isEmpty {
                            selectionSummary
                                .padding(.horizontal, 16)
                        }

                        // Productos
                        ForEach(filtered) { item in
                            productRow(item: item)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 100) // espacio para el botón fijo
                }

                // ── Botón confirmar ───────────────────────────
                confirmBar
            }
            .navigationTitle("Levantar Pedido")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Buscar producto...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(AppTheme.bimboRed)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Limpiar") {
                        withAnimation { quantities = [:] }
                    }
                    .foregroundStyle(.secondary)
                    .disabled(quantities.isEmpty)
                }
            }
            .background(AppTheme.subtleGradient.ignoresSafeArea())
        }
    }

    // MARK: - Total Bar

    private var totalBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total del pedido")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(totalUnits) piezas")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("$\(String(format: "%.2f", totalAmount))")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(totalUnits > 0 ? AppTheme.deepBlue : .secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Todos", selected: selectedCategory == nil) {
                    withAnimation { selectedCategory = nil }
                }
                ForEach(categories, id: \.self) { cat in
                    filterChip(cat, selected: selectedCategory == cat) {
                        withAnimation { selectedCategory = selectedCategory == cat ? nil : cat }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? AppTheme.deepBlue : Color(white: 0.88),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection Summary

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Productos seleccionados", systemImage: "cart.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)
            ForEach(orderItems) { item in
                HStack {
                    Text(item.product.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.quantity) × $\(String(format: "%.2f", item.product.salePrice))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", Double(item.quantity) * item.product.salePrice))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(AppTheme.deepBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(AppTheme.deepBlue.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Product Row

    private func productRow(item: TruckInventoryItem) -> some View {
        let qty = quantities[item.product.sku] ?? 0
        let subtotal = Double(qty) * item.product.salePrice
        let isSelected = qty > 0

        return VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: item.product.symbolName)
                    .foregroundStyle(isSelected ? AppTheme.deepBlue : .secondary)
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background((isSelected ? AppTheme.deepBlue : Color(white: 0.88)),
                                in: Circle())
                    .foregroundStyle(isSelected ? .white : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.product.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.product.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", item.product.salePrice))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.deepBlue)
                    Text("Disp: \(item.available)")
                        .font(.caption2)
                        .foregroundStyle(item.isLowStock ? AppTheme.bimboRed : .secondary)
                }
            }

            // Stepper row — ancho fijo para no desbordar
            HStack(spacing: 0) {
                // Subtotal
                if qty > 0 {
                    Text("= $\(String(format: "%.2f", subtotal))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .contentTransition(.numericText())
                }

                Spacer()

                // Controles − N +
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            let current = quantities[item.product.sku] ?? 0
                            if current > 0 { quantities[item.product.sku] = current - 1 }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(qty > 0 ? AppTheme.deepBlue : .secondary)
                            .background((qty > 0 ? AppTheme.deepBlue : Color(white: 0.85)).opacity(qty > 0 ? 0.12 : 1),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Text("\(qty)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(qty > 0 ? AppTheme.deepBlue : Color(white: 0.6))
                        .contentTransition(.numericText())

                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            quantities[item.product.sku] = (quantities[item.product.sku] ?? 0) + 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                            .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)   // ← evita scroll horizontal
        .background(
            isSelected
                ? AppTheme.deepBlue.opacity(0.06)
                : Color(UIColor.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? AppTheme.deepBlue.opacity(0.25) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Confirm Bar

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                confirmOrder()
            } label: {
                Label(
                    didConfirm ? "Pedido confirmado ✓" : "Confirmar Pedido — $\(String(format: "%.2f", totalAmount))",
                    systemImage: didConfirm ? "checkmark.seal.fill" : "cart.badge.plus"
                )
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(
                    didConfirm ? AppTheme.success : (totalUnits > 0 ? AppTheme.bimboRed : Color(white: 0.75)),
                    in: RoundedRectangle(cornerRadius: 0)
                )
            }
            .buttonStyle(.plain)
            .disabled(totalUnits == 0 || didConfirm)
        }
    }

    // MARK: - Confirm

    private func confirmOrder() {
        let items = orderItems
        viewModel.confirmOrder(storeId: storeId, items: items, notes: notes)
        withAnimation(.spring(response: 0.3)) { didConfirm = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
    }
}

#Preview {
    let vm = RoutePerfectaViewModel()
    LevantarPedidoView(viewModel: vm, storeId: vm.stores.first?.id)
}
