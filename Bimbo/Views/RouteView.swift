import SwiftUI
import MapKit

struct RouteView: View {
    @Bindable var viewModel: RoutePerfectaViewModel
    @State private var path: [AppRoute] = []
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 19.4256, longitude: -99.1458),
            span: MKCoordinateSpan(latitudeDelta: 0.040, longitudeDelta: 0.045)
        )
    )

    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4256, longitude: -99.1458),
        span: MKCoordinateSpan(latitudeDelta: 0.040, longitudeDelta: 0.045)
    )

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    handsFreeCard
                    confirmationBanner
                    metricsGrid
                    routeMap
                    nextStoreCard
                    routeStopsList
                }
                .padding(18)
            }
            .background(pageBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
    }

    private var pageBackground: some View {
        ZStack {
            AppTheme.systemBackground
            AppTheme.subtleGradient.ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ruta de hoy")
                .font(.largeTitle.weight(.bold))
            Text("Copiloto IA para vender mas en menos tiempo")
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressView(value: viewModel.routeProgress)
                .tint(AppTheme.bimboRed)
                .accessibilityLabel("Progreso de ruta")
            Text("\(viewModel.completedCount) de \(viewModel.routeStoreStops.count) tiendas completadas")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var confirmationBanner: some View {
        if let message = viewModel.lastConfirmationMessage {
            Label(message, systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.success)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var metricsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                metric("Tiendas restantes", "\(viewModel.pendingCount)", "storefront.fill", AppTheme.deepBlue)
                metric("Tiempo estimado", "\(viewModel.routeStoreStops.reduce(0) { $0 + $1.estimatedMinutes }) min", "clock.fill", AppTheme.electricBlue)
            }
            GridRow {
                metric("Productos en camion", "\(viewModel.totalAvailableUnits)", "box.truck.fill", AppTheme.success)
                metric("Merma evitada", "\(viewModel.avoidedWaste) pzs", "leaf.fill", AppTheme.bimboRed)
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var routeMap: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.routeStops.sorted { $0.order < $1.order }) { stop in
                Marker(stop.name, systemImage: markerIcon(for: stop), coordinate: stop.coordinate)
                    .tint(markerTint(for: stop))
            }

            if viewModel.routeCoordinates.count > 1 {
                MapPolyline(coordinates: viewModel.routeCoordinates)
                    .stroke(AppTheme.bimboRed, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Deposito + 3 tiendas + regreso", systemImage: "map.fill")
                    .font(.caption.weight(.bold))
                Text("Ruta visual aproximada entre puntos")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    mapPosition = .region(defaultRegion)
                }
            } label: {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            }
            .padding(12)
        }
    }

    private func markerIcon(for stop: RouteStop) -> String {
        switch stop.status {
        case .depot: "building.2.fill"
        case .current: "location.fill"
        case .completed: "checkmark.circle.fill"
        case .pending: "storefront.fill"
        }
    }

    private func markerTint(for stop: RouteStop) -> Color {
        switch stop.status {
        case .depot: AppTheme.deepBlue
        case .current: AppTheme.bimboRed
        case .completed: AppTheme.success
        case .pending: AppTheme.warning
        }
    }

    @ViewBuilder
    private var nextStoreCard: some View {
        if let store = viewModel.nextStore, let stop = viewModel.nextPendingStop {
            VStack(alignment: .leading, spacing: 14) {
                Label("Siguiente destino", systemImage: "location.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.deepBlue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.title2.weight(.bold))
                    Text(stop.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(stop.distance) - \(stop.estimatedMinutes) min estimados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.deepBlue)
                }

                PrimaryButton(title: "Iniciar navegacion", systemImage: "location.north.line.fill") {
                    viewModel.openNavigation(app: .appleMaps, stop: stop)
                }

                HStack(spacing: 8) {
                    navButton("Abrir en Waze", "w.circle.fill", .waze, stop)
                    navButton("Abrir en Google Maps", "g.circle.fill", .googleMaps, stop)
                }
                navButton("Abrir en Apple Maps", "map.fill", .appleMaps, stop)

                PrimaryButton(title: "Entrar a tienda", systemImage: "figure.walk.arrival") {
                    viewModel.startVisit(storeId: store.id)
                    path.append(.storeDetail(store.id))
                }

                if let message = viewModel.mapsStatusMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func navButton(_ title: String, _ icon: String, _ app: NavigationApp, _ stop: RouteStop) -> some View {
        Button {
            viewModel.openNavigation(app: app, stop: stop)
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .foregroundStyle(AppTheme.deepBlue)
                .background(AppTheme.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var handsFreeCard: some View {
        let voice = VoiceService.shared
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Resumen del día", systemImage: "speaker.wave.2.fill")
                    .font(.headline.weight(.bold))
                Spacer()
                VoiceToggleRow()
            }

            Text("Escucha un resumen de tus tiendas, inventario y kilómetros antes de salir.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(viewModel.isGeneratingDaySummary ? "Groq preparando resumen..." : "Resumen generado por Groq + ElevenLabs", systemImage: viewModel.isGeneratingDaySummary ? "sparkles" : "brain.head.profile")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.deepBlue)

            Label(ElevenLabsConfig.isConfigured ? "ElevenLabs configurado" : "Sin API key: se usará voz local", systemImage: ElevenLabsConfig.isConfigured ? "checkmark.circle.fill" : "speaker.wave.1.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ElevenLabsConfig.isConfigured ? AppTheme.success : AppTheme.warning)

            if let error = viewModel.daySummaryErrorMessage {
                Text("Groq: \(error)").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.warning)
            }
            if let error = voice.lastErrorMessage {
                Text(error).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.warning)
            }

            Button {
                if voice.isPlaying { voice.stop() }
                else {
                    Task {
                        let summary = await viewModel.generateDayVoiceSummary()
                        await voice.speak(summary)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if voice.isLoading || viewModel.isGeneratingDaySummary {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: voice.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text(viewModel.isGeneratingDaySummary ? "Generando resumen..." : voice.isLoading ? "Preparando voz..." : voice.isPlaying ? "Detener resumen" : "Escuchar resumen del día")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(voice.isPlaying ? .red : AppTheme.deepBlue)
            .disabled(voice.isLoading || viewModel.isGeneratingDaySummary || !voice.isEnabled)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var routeStopsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paradas")
                .font(.title3.weight(.bold))

            ForEach(viewModel.routeStoreStops.sorted { $0.order < $1.order }) { stop in
                if let store = viewModel.store(for: stop.storeId) {
                    Button {
                        path.append(.storeDetail(store.id))
                    } label: {
                        StoreRouteCard(store: store, stop: stop)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .inventory:
            TruckInventoryView(viewModel: viewModel)
        case .storeDetail(let storeId):
            StoreDetailView(viewModel: viewModel, storeId: storeId, path: $path)
        case .scan(let storeId):
            ScanView(viewModel: viewModel, storeId: storeId, path: $path)
        case .recommendation(let storeId):
            AIRecommendationView(viewModel: viewModel, storeId: storeId, path: $path)
        case .finalOrder(let storeId):
            FinalOrderView(viewModel: viewModel, storeId: storeId, path: $path)
        case .addStore:
            AddStoreView(viewModel: viewModel, path: $path)
        }
    }
}
