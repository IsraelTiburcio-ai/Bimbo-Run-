import SwiftUI

struct AddStoreView: View {
    @Bindable var viewModel: RouteViewModel
    @Binding var path: [AppRoute]

    @State private var name = ""
    @State private var clientId = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var reference = ""
    @State private var type: StoreType = .tiendita
    @State private var visitFrequency: VisitFrequency = .weekly
    @State private var notes = ""
    @State private var didUseLocation = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introCard
                formFields
                locationButton
                PrimaryButton(title: "Guardar tienda", systemImage: "tray.and.arrow.down.fill") {
                    saveStore()
                }
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
            }
            .padding(18)
        }
        .background(AppTheme.subtleGradient.ignoresSafeArea())
        .navigationTitle("Agregar tienda")
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nueva tienda pendiente de validar", systemImage: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.deepBlue)
            Text("Guarda los datos base para sumarla a la ruta. La IA aprendera patrones despues del primer escaneo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var formFields: some View {
        VStack(spacing: 14) {
            textField("Nombre de tienda", text: $name, icon: "storefront")
            textField("Numero de cliente opcional", text: $clientId, icon: "number")
            textField("Nombre del tendero", text: $contactName, icon: "person")
            textField("Telefono opcional", text: $phone, icon: "phone")
            textField("Direccion", text: $address, icon: "mappin.and.ellipse")
            textField("Referencia", text: $reference, icon: "signpost.right")

            pickerCard(title: "Tipo de tienda", systemImage: "building.2") {
                Picker("Tipo de tienda", selection: $type) {
                    ForEach(StoreType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            pickerCard(title: "Frecuencia", systemImage: "calendar.badge.clock") {
                Picker("Frecuencia", selection: $visitFrequency) {
                    ForEach(VisitFrequency.allCases) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Notas", systemImage: "note.text")
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 14))
            }
            .fieldCard()
        }
    }

    private var locationButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                didUseLocation = true
                if address.isEmpty {
                    address = "Ubicacion actual capturada (mock)"
                }
            }
        } label: {
            Label(didUseLocation ? "Ubicacion mock agregada" : "Usar ubicacion actual", systemImage: "location.fill")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .foregroundStyle(didUseLocation ? AppTheme.success : AppTheme.deepBlue)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func textField(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.electricBlue)
                .frame(width: 24)
            TextField(title, text: text)
        }
        .fieldCard()
    }

    private func pickerCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .fieldCard()
    }

    private func saveStore() {
        viewModel.addStore(
            name: name,
            clientId: clientId,
            contactName: contactName,
            phone: phone,
            address: address,
            reference: reference,
            type: type,
            visitFrequency: visitFrequency,
            notes: notes
        )
        path.removeAll()
    }
}

private extension View {
    func fieldCard() -> some View {
        self
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
