import SwiftUI

struct StoreDetailView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    var storeId: UUID
    @Binding var path: [AppRoute]

    // Sheets
    @State private var showShelfCamera   = false
    @State private var showVoiceInput    = false
    @State private var showLevantarPedido = false

    // Checklist: producto más vendido
    @State private var bestSellerExpanded = false
    @State private var bestSellerDone = false
    @State private var bestSellerInput = ""

    // Checklist: baja rotación
    @State private var lowRotationExpanded = false
    @State private var lowRotationDone = false
    @State private var lowRotationInput = ""

    // Checklist: última visita
    @State private var visitDone = false

    // Checklist: piezas a retirar
    @State private var withdrawalExpanded = false
    @State private var withdrawalDone = false
    @State private var withdrawalQty = 0

    private var store: Store? { viewModel.store(for: storeId) }

    var body: some View {
        ScrollView {
            if let store {
                VStack(alignment: .leading, spacing: 18) {
                    hero(store)
                    checklistCard(store)
                    detailGrid(store)
                    productHistory(store)
                    visitHistory(store)

                    PrimaryButton(title: "Escanear productos", systemImage: "qrcode.viewfinder") {
                        viewModel.startVisit(storeId: store.id)
                        path.append(.scan(store.id))
                    }

                    PrimaryButton(title: "Fotografiar Anaquel", systemImage: "camera.viewfinder") {
                        showShelfCamera = true
                    }

                    // ── Levantar Pedido ──────────────────────────
                    Button {
                        viewModel.startVisit(storeId: store.id)
                        showLevantarPedido = true
                    } label: {
                        Label("Levantar Pedido", systemImage: "cart.fill.badge.plus")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(AppTheme.bimboRed, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            } else {
                ContentUnavailableView("Tienda no encontrada", systemImage: "exclamationmark.triangle")
            }
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle(store?.name ?? "Detalle")
        .sheet(isPresented: $showShelfCamera) {
            if let store {
                ShelfCameraView(store: store, inventory: viewModel.truckInventory)
            }
        }
        .sheet(isPresented: $showVoiceInput) {
            if let store {
                VoiceStoreInputView(store: store) { fields in
                    viewModel.applyVoiceStoreFields(storeId: store.id, fields: fields)
                }
            }
        }
        .sheet(isPresented: $showLevantarPedido) {
            LevantarPedidoView(viewModel: viewModel, storeId: storeId)
        }
    }

    // MARK: - Hero

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

            HStack {
                Text("Presupuesto: $\(Int(store.estimatedBudget))")
                    .font(.headline.weight(.bold))
                Spacer()
                // Botón de micrófono IA
                Button {
                    showVoiceInput = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Actualizar con voz")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.deepBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.92), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: - Checklist Interactivo

    private func checklistCard(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Checklist operativo", systemImage: "checklist")
                .font(.headline.weight(.bold))

            // Estáticos
            staticRow("Saludar y confirmar presupuesto del día")
            staticRow("Revisar frente y huecos de anaquel")
            staticRow("Escanear QRs de caducidad por producto")
            staticRow("Aceptar recomendación IA y confirmar pedido")

            Divider().padding(.vertical, 2)

            // ── Más vendido ──────────────────────────────────
            interactiveRow(
                icon: "star.fill",
                tint: AppTheme.warning,
                title: "Preguntar por el producto más vendido",
                badge: bestSellerDone ? (store.bestSellers.first ?? "") : nil,
                done: bestSellerDone,
                expanded: bestSellerExpanded,
                onToggle: { withAnimation(.spring(response: 0.3)) { bestSellerExpanded.toggle() } }
            )

            if bestSellerExpanded && !bestSellerDone {
                inputRow(
                    placeholder: "Ej: Medias Noches, Pan Blanco...",
                    text: $bestSellerInput
                ) {
                    viewModel.recordBestSeller(storeId: storeId, product: bestSellerInput)
                    bestSellerDone = true
                    bestSellerExpanded = false
                    bestSellerInput = ""
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Menor rotación ───────────────────────────────
            interactiveRow(
                icon: "arrow.down.forward.circle.fill",
                tint: AppTheme.bimboRed,
                title: "Preguntar por el producto con menor rotación",
                badge: lowRotationDone ? (store.lowRotationProducts.first ?? "") : nil,
                done: lowRotationDone,
                expanded: lowRotationExpanded,
                onToggle: { withAnimation(.spring(response: 0.3)) { lowRotationExpanded.toggle() } }
            )

            if lowRotationExpanded && !lowRotationDone {
                inputRow(
                    placeholder: "Ej: Gansito, Pan Integral...",
                    text: $lowRotationInput
                ) {
                    viewModel.recordLowRotation(storeId: storeId, product: lowRotationInput)
                    lowRotationDone = true
                    lowRotationExpanded = false
                    lowRotationInput = ""
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Última visita ────────────────────────────────
            interactiveRow(
                icon: "clock.badge.checkmark.fill",
                tint: AppTheme.electricBlue,
                title: "Registrar última visita",
                badge: visitDone ? store.lastVisit : nil,
                done: visitDone,
                expanded: false,
                onToggle: {
                    guard !visitDone else { return }
                    viewModel.recordTodayVisit(storeId: storeId)
                    withAnimation(.spring(response: 0.3)) { visitDone = true }
                }
            )

            // ── Piezas a retirar ─────────────────────────────
            interactiveRow(
                icon: "arrow.uturn.backward.circle.fill",
                tint: AppTheme.success,
                title: "Piezas a retirar",
                badge: withdrawalDone ? "\(withdrawalQty) piezas retiradas" : nil,
                done: withdrawalDone,
                expanded: withdrawalExpanded,
                onToggle: { withAnimation(.spring(response: 0.3)) { withdrawalExpanded.toggle() } }
            )

            if withdrawalExpanded && !withdrawalDone {
                withdrawalRow()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Row builders

    private func staticRow(_ title: String) -> some View {
        Label(title, systemImage: "circle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func interactiveRow(
        icon: String,
        tint: Color,
        title: String,
        badge: String?,
        done: Bool,
        expanded: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .foregroundStyle(done ? AppTheme.success : tint)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(done ? .secondary : .primary)
                    if let badge, done {
                        Text(badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                Spacer()

                if !done {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func inputRow(placeholder: String, text: Binding<String>, onSave: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Button("Guardar") { onSave() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.success)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.leading, 28)
    }

    private func withdrawalRow() -> some View {
        HStack(spacing: 14) {
            Text("Piezas:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Stepper custom
            HStack(spacing: 2) {
                Button {
                    if withdrawalQty > 0 { withdrawalQty -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(AppTheme.deepBlue)
                        .background(AppTheme.deepBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text("\(withdrawalQty)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.deepBlue)

                Button {
                    withdrawalQty += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.white)
                        .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Guardar") {
                viewModel.recordWithdrawal(storeId: storeId, quantity: withdrawalQty)
                withdrawalDone = true
                withdrawalExpanded = false
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.success)
            .disabled(withdrawalQty == 0)
        }
        .padding(.leading, 28)
    }

    // MARK: - Detail grid, histories

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
            Image(systemName: icon).foregroundStyle(tint)
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
