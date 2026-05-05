import Foundation
import MapKit
import Observation

enum AppRoute: Hashable {
    case addStore
    case inventory
    case storeDetail(UUID)
    case scan(UUID?)
    case recommendation(UUID?)
    case finalOrder(UUID?)
}

typealias RouteViewModel = RoutePerfectaViewModel

@Observable
final class RoutePerfectaViewModel {
    var stores: [Store]
    var routeStops: [RouteStop]
    var truckInventory: [TruckInventoryItem]
    var savedMinutes: Int
    var avoidedWaste: Int
    var estimatedSales: Double
    var removedProductsCount: Int
    var lastConfirmationMessage: String?
    var mapsStatusMessage: String?
    var scannedProducts: [ScannedProduct]
    var scanAlerts: [String]
    var lastScannedProduct: ScannedProduct?
    var daySummaryErrorMessage: String?
    var isGeneratingDaySummary = false

    // AI
    var latestScanResult: ScanResult?
    var aiErrorMessage: String?
    var isGeneratingAI = false

    private let aiService: AIRecommendationService = GroqAIRecommendationService()
    private let routeSummaryService = RouteSummaryService()
    private let navigationService = NavigationAppService()

    init() {
        let products = Product.mockProducts
        let initialStores = Store.mockStores(products: products)
        let initialRouteStops = RouteStop.mockStops(for: initialStores)
        let initialTruckInventory = TruckInventoryItem.mockInventory(products: products)

        self.stores = initialStores
        self.routeStops = initialRouteStops
        self.truckInventory = initialTruckInventory
        self.savedMinutes = 24
        self.avoidedWaste = 9
        self.estimatedSales = 1850
        self.removedProductsCount = 4
        self.scannedProducts = []
        self.scanAlerts = []
    }

    var completedCount: Int {
        stores.filter { $0.status == .completed }.count
    }

    var pendingCount: Int {
        stores.filter { $0.status != .completed }.count
    }

    var daySummaryText: String {
        let totalKm = routeStops.reduce(0.0) { $0 + $1.distanceKm }
        let firstStop = nextStore?.name ?? "sin tienda asignada"
        let topItems = truckInventory
            .sorted { $0.available > $1.available }
            .prefix(3)
            .map(\.product.name)
            .joined(separator: ", ")
        return "Buenos dias. Tienes \(pendingCount) tiendas pendientes y \(String(format: "%.1f", totalKm)) kilometros estimados. Primera parada: \(firstStop). Enfocate en revisar anaquel, caducidades y surtir solo lo necesario. Inventario fuerte: \(topItems)."
    }

    var routeProgress: Double {
        let storeStops = routeStoreStops
        guard !storeStops.isEmpty else { return 0 }
        return Double(storeStops.filter { $0.status == .completed }.count) / Double(storeStops.count)
    }

    var routeStoreStops: [RouteStop] {
        routeStops.filter { $0.storeId != nil }
    }

    var nextPendingStop: RouteStop? {
        routeStoreStops.sorted { $0.order < $1.order }.first { $0.status != .completed }
    }

    var nextStore: Store? {
        guard let nextPendingStop else { return nil }
        return store(for: nextPendingStop.storeId)
    }

    var routeCoordinates: [CLLocationCoordinate2D] {
        routeStops.sorted { $0.order < $1.order }.map(\.coordinate)
    }

    var lowInventoryItems: [TruckInventoryItem] {
        truckInventory.filter(\.isLowStock)
    }

    var totalAvailableUnits: Int {
        truckInventory.reduce(0) { $0 + $1.available }
    }

    var totalReservedSuggested: Int {
        truckInventory.reduce(0) { $0 + $1.reservedSuggested }
    }

    var totalReturnedUnits: Int {
        truckInventory.reduce(0) { $0 + $1.returned }
    }

    func store(for id: UUID?) -> Store? {
        guard let id else { return nextStore ?? stores.first }
        return stores.first { $0.id == id }
    }

    func inventoryItem(for product: Product) -> TruckInventoryItem? {
        truckInventory.first { $0.product.sku == product.sku }
    }

    func startVisit(storeId: UUID?) {
        guard let storeId else { return }
        updateStore(storeId) { store in
            if store.status != .completed {
                store.status = .inProgress
                store.aiHint = "Escaneo recomendado"
            }
        }
        updateStop(storeId) { stop in
            if stop.status != .completed {
                stop.status = .current
            }
        }
    }

    func addStore(
        name: String,
        clientId: String,
        contactName: String,
        phone: String,
        address: String,
        reference: String,
        type: StoreType,
        visitFrequency: VisitFrequency,
        notes: String
    ) {
        let fallbackProduct = Product.mockProducts[0]
        let store = Store(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Por validar" : clientId,
            contactName: contactName,
            phone: phone,
            address: address,
            reference: reference,
            type: type,
            visitFrequency: visitFrequency,
            status: .pending,
            aiHint: "Nueva tienda pendiente de validar",
            lastVisit: "Sin visitas previas",
            lastReturn: notes.isEmpty ? "Sin historial" : notes,
            estimatedBudget: 1200,
            bestSellers: ["Por aprender"],
            lowRotationProducts: ["Por aprender"],
            lastDeliveredProducts: [
                OrderItem(product: fallbackProduct, quantity: 0, action: .suggested, note: "Primer pedido pendiente", availableInTruck: 0)
            ],
            visitHistory: ["Alta manual creada hoy. Pendiente validar anaquel."],
            isNewPendingValidation: true
        )
        stores.append(store)
        routeStops.append(
            RouteStop(
                storeId: store.id,
                order: routeStops.count,
                name: store.name,
                address: store.address,
                latitude: 19.4354 + Double(routeStops.count) * 0.006,
                longitude: -99.1490 - Double(routeStops.count) * 0.004,
                estimatedMinutes: 14,
                distanceKm: 2.4,
                eta: "Pendiente",
                distance: "-- km",
                status: .pending,
                routeNote: "Nueva parada agregada manualmente"
            )
        )
    }

    func mockScanResult(storeId: UUID?) -> ScanResult {
        let panBlanco = product(sku: "PAN-BLANCO")
        let mediasNoches = product(sku: "MEDIAS-NOCHES")
        let gansito = product(sku: "GANSITO")
        let takis = product(sku: "TAKIS")

        let scanBasedRemove = scannedProducts
            .filter { $0.expirationRisk != .safe }
            .compactMap { scanned -> OrderItem? in
                guard let product = Product.mockProducts.first(where: { $0.sku == scanned.sku }) else { return nil }
                return orderItem(
                    product: product,
                    quantity: max(scanned.quantity, 1),
                    action: .remove,
                    note: scanned.expirationRisk == .expired ? "Caducado en QR lote \(scanned.batch)" : "Proximo a caducar lote \(scanned.batch)"
                )
            }

        let remove = scanBasedRemove + [
            orderItem(product: panBlanco, quantity: 2, action: .remove, note: "Proximo a caducar"),
            orderItem(product: gansito, quantity: 1, action: .remove, note: "Baja rotacion detectada")
        ]
        let replenish = [
            orderItem(product: mediasNoches, quantity: 8, action: .replenish, note: "Alta rotacion"),
            orderItem(product: panBlanco, quantity: 6, action: .replenish, note: "Frente incompleto")
        ]
        let suggested = [
            orderItem(product: takis, quantity: 10, action: .suggested, note: "Snack recomendado por ubicacion")
        ]
        let allStockItems = replenish + suggested
        let alerts = allStockItems
            .filter { !$0.hasEnoughInventory }
            .map { "Inventario insuficiente para \($0.product.name): hay \($0.availableInTruck), se sugieren \($0.quantity)." }

        return ScanResult(
            storeId: storeId,
            productsToRemove: remove,
            productsToReplenish: replenish,
            suggestedProducts: suggested,
            layoutSuggestions: [
                "Colocar productos de alta rotacion al centro",
                "Subir Medias Noches a nivel de vista",
                "Retirar producto proximo a caducar antes de surtir"
            ],
            inventoryAlerts: alerts
        )
    }

    func buildOrder(from result: ScanResult) -> [OrderItem] {
        result.productsToReplenish + result.suggestedProducts
    }

    func confirmOrder(storeId: UUID?, items: [OrderItem], notes: String) {
        let sellableItems = items.filter(\.needsTruckStock)
        for item in sellableItems {
            guard let index = truckInventory.firstIndex(where: { $0.product.sku == item.product.sku }) else { continue }
            let quantityToDiscount = min(item.quantity, truckInventory[index].available)
            truckInventory[index].available -= quantityToDiscount
            truckInventory[index].reservedSuggested = max(0, truckInventory[index].reservedSuggested - quantityToDiscount)
            estimatedSales += Double(quantityToDiscount) * item.product.salePrice
        }

        let removedItems = latestScanResult?.productsToRemove ?? mockScanResult(storeId: storeId).productsToRemove
        let removedUnits = removedItems.reduce(0) { $0 + $1.quantity }
        removedProductsCount += removedUnits
        avoidedWaste += removedUnits

        for item in removedItems {
            if let index = truckInventory.firstIndex(where: { $0.product.sku == item.product.sku }) {
                truckInventory[index].returned += item.quantity
            }
        }

        if let storeId {
            updateStore(storeId) { store in
                store.status = .completed
                store.aiHint = "Pedido confirmado"
                store.lastVisit = "Hoy"
                store.lastReturn = "\(removedUnits) piezas retiradas"
                store.lastDeliveredProducts = sellableItems
                store.visitHistory.insert("Pedido confirmado: \(sellableItems.reduce(0) { $0 + $1.quantity }) piezas. \(notes)", at: 0)
                store.isNewPendingValidation = false
            }
            updateStop(storeId) { stop in
                stop.status = .completed
                stop.routeNote = "Tienda completada. Siguiente parada lista."
            }
            markNextStoreAsCurrent()
        }

        savedMinutes += 18
        lastConfirmationMessage = "Pedido confirmado. Inventario actualizado y tienda completada."
    }

    @MainActor
    func openNavigation(app: NavigationApp, stop: RouteStop?) {
        guard let stop else {
            mapsStatusMessage = "No hay una tienda pendiente para navegar."
            return
        }
        mapsStatusMessage = navigationService.open(app: app, latitude: stop.latitude, longitude: stop.longitude, name: stop.name)
    }

    @MainActor
    func generateDayVoiceSummary() async -> String {
        isGeneratingDaySummary = true
        daySummaryErrorMessage = nil
        do {
            let pendingStores = routeStoreStops
                .sorted { $0.order < $1.order }
                .filter { $0.status != .completed }
                .compactMap { store(for: $0.storeId) }
            let summary = try await routeSummaryService.generateSummary(
                pendingStores: pendingStores,
                nextStore: nextStore,
                routeStops: routeStops,
                inventory: truckInventory,
                avoidedWaste: avoidedWaste,
                savedMinutes: savedMinutes
            )
            isGeneratingDaySummary = false
            return summary
        } catch {
            daySummaryErrorMessage = error.localizedDescription
            isGeneratingDaySummary = false
            return daySummaryText
        }
    }

    func resetScan(storeId: UUID?) {
        scannedProducts = []
        scanAlerts = []
        lastScannedProduct = nil
        latestScanResult = nil
        aiErrorMessage = nil
        startVisit(storeId: storeId)
    }

    @discardableResult
    func processScannedPayload(_ payload: String) -> ScannedProduct? {
        guard !scannedProducts.contains(where: { $0.rawPayload == payload }) else {
            return nil
        }

        do {
            let product = try ScannedProduct.parse(payload)
            scannedProducts.insert(product, at: 0)
            lastScannedProduct = product

            switch product.expirationRisk {
            case .expired:
                scanAlerts.insert("\(product.name) lote \(product.batch) esta caducado. Retiralo del anaquel.", at: 0)
            case .nearExpiration:
                scanAlerts.insert("\(product.name) lote \(product.batch) caduca pronto. Revisa rotacion o retiro.", at: 0)
            case .safe:
                break
            }
            return product
        } catch {
            scanAlerts.insert("QR invalido o incompleto. Usa el formato de producto Bimbo.", at: 0)
            return nil
        }
    }

    @MainActor
    func generateAIRecommendation(storeId: UUID?) async {
        guard let store = store(for: storeId) else {
            latestScanResult = mockScanResult(storeId: storeId)
            return
        }
        isGeneratingAI = true
        aiErrorMessage = nil
        do {
            latestScanResult = try await aiService.generateRecommendation(store: store, inventory: truckInventory, scannedProducts: scannedProducts)
        } catch {
            aiErrorMessage = error.localizedDescription
            latestScanResult = mockScanResult(storeId: storeId)
        }
        isGeneratingAI = false
    }

    func inventoryAvailability(for items: [OrderItem]) -> [String] {
        items.filter { !$0.hasEnoughInventory }.map {
            "\($0.product.name): disponible \($0.availableInTruck), sugerido \($0.quantity)"
        }
    }

    private func product(sku: String) -> Product {
        Product.mockProducts.first { $0.sku == sku } ?? Product.mockProducts[0]
    }

    private func orderItem(product: Product, quantity: Int, action: OrderAction, note: String) -> OrderItem {
        OrderItem(
            product: product,
            quantity: quantity,
            action: action,
            note: note,
            availableInTruck: inventoryItem(for: product)?.available ?? 0
        )
    }

    private func updateStore(_ storeId: UUID, update: (inout Store) -> Void) {
        guard let index = stores.firstIndex(where: { $0.id == storeId }) else { return }
        update(&stores[index])
    }

    private func updateStop(_ storeId: UUID, update: (inout RouteStop) -> Void) {
        guard let index = routeStops.firstIndex(where: { $0.storeId == storeId }) else { return }
        update(&routeStops[index])
    }

    private func markNextStoreAsCurrent() {
        guard let nextIndex = routeStops
            .sorted(by: { $0.order < $1.order })
            .first(where: { $0.storeId != nil && $0.status == .pending })
            .flatMap({ next in routeStops.firstIndex(where: { $0.id == next.id }) }) else {
            return
        }
        routeStops[nextIndex].status = .current
        if let storeId = routeStops[nextIndex].storeId {
            updateStore(storeId) { store in
                if store.status == .pending {
                    store.aiHint = "Siguiente destino"
                }
            }
        }
    }
}

extension Product {
    static let mockProducts: [Product] = [
        Product(sku: "PAN-BLANCO", name: "Pan Bimbo Natural 620g", category: "Pan de caja", purchasePrice: 38, salePrice: 50, symbolName: "shippingbox.fill"),
        Product(sku: "PAN-INTEGRAL", name: "Pan Integral 620g", category: "Pan de caja", purchasePrice: 43, salePrice: 56, symbolName: "leaf.fill"),
        Product(sku: "PAN-CERO-CERO", name: "Pan Cero Cero", category: "Pan de caja", purchasePrice: 48, salePrice: 62, symbolName: "0.circle.fill"),
        Product(sku: "PAN-ARTESANO", name: "Pan Artesano", category: "Pan de caja", purchasePrice: 52, salePrice: 66, symbolName: "seal.fill"),
        Product(sku: "PAN-MULTIGRANO", name: "Pan Multigrano", category: "Pan de caja", purchasePrice: 54, salePrice: 68, symbolName: "circle.grid.3x3.fill"),
        Product(sku: "MEDIAS-NOCHES", name: "Medias Noches Bimbo", category: "Pan especial", purchasePrice: 20, salePrice: 28, symbolName: "takeoutbag.and.cup.and.straw.fill"),
        Product(sku: "BIMBOLLOS", name: "Bimbollos", category: "Pan especial", purchasePrice: 12, salePrice: 17, symbolName: "bag.fill"),
        Product(sku: "PAN-HOT-DOG", name: "Pan Hot Dog", category: "Pan especial", purchasePrice: 18, salePrice: 24, symbolName: "rectangle.fill"),
        Product(sku: "PAN-HAMBURGUESA", name: "Pan Hamburguesa", category: "Pan especial", purchasePrice: 22, salePrice: 29, symbolName: "circle.fill"),
        Product(sku: "PANQUECHOX", name: "Panquechox", category: "Bolleria", purchasePrice: 19, salePrice: 26, symbolName: "birthday.cake.fill"),
        Product(sku: "ROLES-CANELA", name: "Roles con Canela", category: "Bolleria", purchasePrice: 16, salePrice: 21, symbolName: "circle.grid.2x2.fill"),
        Product(sku: "MANTECHOX", name: "Mantechox Hershey's", category: "Bolleria", purchasePrice: 18, salePrice: 24, symbolName: "heart.fill"),
        Product(sku: "BARRAS-MULTIGRANO", name: "Barras Multigrano", category: "Barras", purchasePrice: 11, salePrice: 16, symbolName: "rectangle.fill"),
        Product(sku: "DONAS-CHOCOLATE", name: "Donas con Chocolate", category: "Pan dulce", purchasePrice: 13, salePrice: 19, symbolName: "circle.circle.fill"),
        Product(sku: "DONAS-AZUCARADAS", name: "Donas Azucaradas", category: "Pan dulce", purchasePrice: 11, salePrice: 16, symbolName: "circle"),
        Product(sku: "CONCHAS", name: "Conchas de Vainilla", category: "Pan dulce", purchasePrice: 13, salePrice: 19, symbolName: "cloud.fill"),
        Product(sku: "BIMBUÑUELOS", name: "Bimbuñuelos", category: "Pan dulce", purchasePrice: 13, salePrice: 19, symbolName: "sparkles"),
        Product(sku: "LITTLE-BITES", name: "Little Bites", category: "Pan dulce", purchasePrice: 17, salePrice: 23, symbolName: "square.grid.2x2.fill"),
        Product(sku: "MINI-MANTECADAS", name: "Mini Mantecadas", category: "Pan dulce", purchasePrice: 15, salePrice: 21, symbolName: "birthday.cake.fill"),
        Product(sku: "BRAN-FRUT", name: "Barritas Bran Frut", category: "Barras", purchasePrice: 10, salePrice: 15, symbolName: "capsule.fill"),
        Product(sku: "PAN-TOSTADO-BRIOCHE", name: "Pan Tostado Brioche", category: "Tostados", purchasePrice: 15, salePrice: 21, symbolName: "square.fill"),
        Product(sku: "MINI-PAN-TOSTADO", name: "Mini Pan Tostado", category: "Tostados", purchasePrice: 15, salePrice: 21, symbolName: "square.on.square.fill"),
        Product(sku: "GANSITO", name: "Gansito", category: "Pastelito", purchasePrice: 16, salePrice: 23, symbolName: "birthday.cake.fill"),
        Product(sku: "TAKIS", name: "Takis", category: "Snack", purchasePrice: 14, salePrice: 22, symbolName: "flame.fill"),
        Product(sku: "BIM-NITO-001", name: "Nito", category: "Pastelito", purchasePrice: 15, salePrice: 22, symbolName: "seal.fill")
    ]
}

extension TruckInventoryItem {
    static func mockInventory(products: [Product]) -> [TruckInventoryItem] {
        let quantities: [String: Int] = [
            "PAN-BLANCO": 80,
            "PAN-INTEGRAL": 60,
            "PAN-CERO-CERO": 40,
            "PAN-ARTESANO": 30,
            "PAN-MULTIGRANO": 25,
            "MEDIAS-NOCHES": 50,
            "BIMBOLLOS": 60,
            "PAN-HOT-DOG": 45,
            "PAN-HAMBURGUESA": 40,
            "PANQUECHOX": 75,
            "ROLES-CANELA": 60,
            "MANTECHOX": 50,
            "BARRAS-MULTIGRANO": 80,
            "DONAS-CHOCOLATE": 50,
            "DONAS-AZUCARADAS": 50,
            "CONCHAS": 60,
            "BIMBUÑUELOS": 50,
            "LITTLE-BITES": 70,
            "MINI-MANTECADAS": 70,
            "BRAN-FRUT": 100,
            "PAN-TOSTADO-BRIOCHE": 80,
            "MINI-PAN-TOSTADO": 80,
            "GANSITO": 36,
            "TAKIS": 24,
            "BIM-NITO-001": 42
        ]

        return products.map { product in
            let available = quantities[product.sku] ?? 20
            return TruckInventoryItem(
                product: product,
                available: available,
                reservedSuggested: min(max(available / 4, 4), 18),
                returned: product.sku == "PAN-BLANCO" ? 2 : product.sku == "GANSITO" ? 1 : 0,
                lowStockThreshold: max(6, available / 10)
            )
        }
    }
}

extension Store {
    static func mockStores(products: [Product]) -> [Store] {
        func product(_ sku: String) -> Product {
            products.first { $0.sku == sku } ?? products[0]
        }

        return [
            Store(
                name: "Abarrotes Lupita",
                clientId: "CLI-20418",
                contactName: "Lupita Hernandez",
                phone: "55 1234 8890",
                address: "Av. Hidalgo 128, Centro",
                reference: "Esquina con Morelos",
                type: .abarrotes,
                visitFrequency: .twiceWeekly,
                status: .inProgress,
                aiHint: "Alta prioridad",
                lastVisit: "Ayer, 9:20 AM",
                lastReturn: "3 piezas Pan Blanco",
                estimatedBudget: 2800,
                bestSellers: ["Medias Noches Bimbo", "Barras Multigrano", "Donas con Chocolate"],
                lowRotationProducts: ["Pan Multigrano", "Gansito"],
                lastDeliveredProducts: [
                    OrderItem(product: product("MEDIAS-NOCHES"), quantity: 10, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("BARRAS-MULTIGRANO"), quantity: 14, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("DONAS-CHOCOLATE"), quantity: 8, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
                ],
                visitHistory: ["Ayer: alta venta de barras y pan dulce", "Semana pasada: evitar exceso de pan de caja"]
            ),
            Store(
                name: "Mini Super El Sol",
                clientId: "CLI-18302",
                contactName: "Carlos Ruiz",
                phone: "55 8877 1130",
                address: "Calle Norte 45, Roma",
                reference: "Frente al parque",
                type: .minisuper,
                visitFrequency: .weekly,
                status: .pending,
                aiHint: "Revisar caducidad",
                lastVisit: "Hace 3 dias",
                lastReturn: "1 pieza Gansito",
                estimatedBudget: 2100,
                bestSellers: ["Bimbollos", "Pan Hamburguesa", "Little Bites"],
                lowRotationProducts: ["Pan Cero Cero", "Gansito"],
                lastDeliveredProducts: [
                    OrderItem(product: product("BIMBOLLOS"), quantity: 12, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("LITTLE-BITES"), quantity: 10, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("PAN-HAMBURGUESA"), quantity: 8, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
                ],
                visitHistory: ["Hace 3 dias: baja rotacion de Gansito", "Semana 15: revisar caducidad de pan"]
            ),
            Store(
                name: "Miscelanea San Jose",
                clientId: "CLI-98211",
                contactName: "Marta Lopez",
                phone: "55 5544 2210",
                address: "Privada Gardenias 22",
                reference: "Porton rojo",
                type: .tiendita,
                visitFrequency: .twiceWeekly,
                status: .pending,
                aiHint: "Reposicion normal",
                lastVisit: "Lunes pasado",
                lastReturn: "Sin devolucion",
                estimatedBudget: 1600,
                bestSellers: ["Barritas Bran Frut", "Roles con Canela", "Nito"],
                lowRotationProducts: ["Pan Integral", "Pan Multigrano"],
                lastDeliveredProducts: [
                    OrderItem(product: product("BRAN-FRUT"), quantity: 16, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("ROLES-CANELA"), quantity: 8, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: product("BIM-NITO-001"), quantity: 6, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
                ],
                visitHistory: ["Lunes: buena venta de snacks", "Recomendacion: evitar exceso de pan integral"]
            )
        ]
    }
}

extension RouteStop {
    static func mockStops(for stores: [Store]) -> [RouteStop] {
        let depotLatitude = 19.4327
        let depotLongitude = -99.1332
        let coordinates: [(Double, Double, Int, Double)] = [
            (19.4361, -99.1419, 8, 1.2),
            (19.4257, -99.1596, 15, 2.8),
            (19.4146, -99.1464, 20, 4.1)
        ]

        let start = RouteStop(
            storeId: nil,
            order: 0,
            name: "Deposito Norte",
            address: "Centro de distribucion",
            latitude: depotLatitude,
            longitude: depotLongitude,
            estimatedMinutes: 0,
            distanceKm: 0,
            eta: "Salida",
            distance: "0 km",
            status: .depot,
            routeNote: "Carga inicial del camion"
        )

        let storeStops = stores.enumerated().map { index, store in
            let coordinate = coordinates[index]
            return RouteStop(
                storeId: store.id,
                order: index + 1,
                name: store.name,
                address: store.address,
                latitude: coordinate.0,
                longitude: coordinate.1,
                estimatedMinutes: coordinate.2,
                distanceKm: coordinate.3,
                eta: index == 0 ? "9:20 AM" : index == 1 ? "10:05 AM" : "11:10 AM",
                distance: String(format: "%.1f km", coordinate.3),
                status: store.status == .completed ? .completed : store.status == .inProgress ? .current : .pending,
                routeNote: index == 0 ? "Dentro del radio de llegada" : "Orden sugerido por tiempo"
            )
        }

        let end = RouteStop(
            storeId: nil,
            order: stores.count + 1,
            name: "Regreso a deposito",
            address: "Centro de distribucion",
            latitude: depotLatitude,
            longitude: depotLongitude,
            estimatedMinutes: 18,
            distanceKm: 3.6,
            eta: "12:10 PM",
            distance: "3.6 km",
            status: .depot,
            routeNote: "Cierre de ruta y devoluciones"
        )

        return [start] + storeStops + [end]
    }
}
