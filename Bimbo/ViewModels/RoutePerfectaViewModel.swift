import Foundation
import Observation

enum AppRoute: Hashable {
    case addStore
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

    // AI
    var latestScanResult: ScanResult?
    var aiErrorMessage: String?
    var isGeneratingAI = false

    private let aiService: AIRecommendationService = GroqAIRecommendationService()

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
    }

    var completedCount: Int {
        stores.filter { $0.status == .completed }.count
    }

    var pendingCount: Int {
        stores.filter { $0.status != .completed }.count
    }

    var routeProgress: Double {
        guard !routeStops.isEmpty else { return 0 }
        return Double(routeStops.filter { $0.status == .completed }.count) / Double(routeStops.count)
    }

    var nextPendingStop: RouteStop? {
        routeStops.sorted { $0.order < $1.order }.first { $0.status != .completed }
    }

    var nextStore: Store? {
        guard let nextPendingStop else { return nil }
        return store(for: nextPendingStop.storeId)
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
                stop.status = .inProgress
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
                order: routeStops.count + 1,
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

        let remove = [
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

        let removedUnits = mockScanResult(storeId: storeId).productsToRemove.reduce(0) { $0 + $1.quantity }
        removedProductsCount += removedUnits
        avoidedWaste += removedUnits

        if let index = truckInventory.firstIndex(where: { $0.product.sku == "PAN-BLANCO" }) {
            truckInventory[index].returned += 2
        }
        if let index = truckInventory.firstIndex(where: { $0.product.sku == "GANSITO" }) {
            truckInventory[index].returned += 1
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
        }

        savedMinutes += 18
        lastConfirmationMessage = "Pedido confirmado. Inventario actualizado y tienda completada."
    }

    func openMapsMock() {
        mapsStatusMessage = "Maps/Waze se conectara aqui en la version real."
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
            latestScanResult = try await aiService.generateRecommendation(store: store, inventory: truckInventory)
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
}

extension Product {
    static let mockProducts: [Product] = [
        Product(sku: "PAN-BLANCO", name: "Pan Blanco", category: "Pan", purchasePrice: 38, salePrice: 48, symbolName: "shippingbox.fill"),
        Product(sku: "MEDIAS-NOCHES", name: "Medias Noches", category: "Pan", purchasePrice: 42, salePrice: 56, symbolName: "takeoutbag.and.cup.and.straw.fill"),
        Product(sku: "GANSITO", name: "Gansito", category: "Pastelito", purchasePrice: 16, salePrice: 23, symbolName: "birthday.cake.fill"),
        Product(sku: "TAKIS", name: "Takis", category: "Snack", purchasePrice: 14, salePrice: 22, symbolName: "flame.fill"),
        Product(sku: "NITO", name: "Nito", category: "Pastelito", purchasePrice: 15, salePrice: 22, symbolName: "seal.fill")
    ]
}

extension TruckInventoryItem {
    static func mockInventory(products: [Product]) -> [TruckInventoryItem] {
        [
            TruckInventoryItem(product: products[0], available: 34, reservedSuggested: 18, returned: 2, lowStockThreshold: 8),
            TruckInventoryItem(product: products[1], available: 20, reservedSuggested: 16, returned: 0, lowStockThreshold: 6),
            TruckInventoryItem(product: products[2], available: 9, reservedSuggested: 5, returned: 1, lowStockThreshold: 5),
            TruckInventoryItem(product: products[3], available: 12, reservedSuggested: 18, returned: 0, lowStockThreshold: 6),
            TruckInventoryItem(product: products[4], available: 16, reservedSuggested: 6, returned: 1, lowStockThreshold: 5)
        ]
    }
}

extension Store {
    static func mockStores(products: [Product]) -> [Store] {
        [
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
                bestSellers: ["Medias Noches", "Pan Blanco", "Takis"],
                lowRotationProducts: ["Pan Integral", "Gansito"],
                lastDeliveredProducts: [
                    OrderItem(product: products[0], quantity: 12, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: products[1], quantity: 10, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
                ],
                visitHistory: ["Ayer: alta venta de Medias Noches", "Semana pasada: retirar Pan Blanco proximo a caducar"]
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
                bestSellers: ["Pan Blanco", "Nito"],
                lowRotationProducts: ["Gansito"],
                lastDeliveredProducts: [
                    OrderItem(product: products[0], quantity: 10, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: products[2], quantity: 6, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
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
                bestSellers: ["Takis", "Nito"],
                lowRotationProducts: ["Pan Integral"],
                lastDeliveredProducts: [
                    OrderItem(product: products[3], quantity: 8, action: .replenish, note: "Pedido anterior", availableInTruck: 0),
                    OrderItem(product: products[4], quantity: 6, action: .replenish, note: "Pedido anterior", availableInTruck: 0)
                ],
                visitHistory: ["Lunes: buena venta de snacks", "Recomendacion: evitar exceso de pan integral"]
            )
        ]
    }
}

extension RouteStop {
    static func mockStops(for stores: [Store]) -> [RouteStop] {
        stores.enumerated().map { index, store in
            RouteStop(
                storeId: store.id,
                order: index + 1,
                eta: index == 0 ? "9:20 AM" : index == 1 ? "10:05 AM" : "11:10 AM",
                distance: index == 0 ? "1.2 km" : index == 1 ? "2.8 km" : "4.1 km",
                status: store.status,
                routeNote: index == 0 ? "Dentro del radio de llegada" : "Orden sugerido por tiempo"
            )
        }
    }
}
