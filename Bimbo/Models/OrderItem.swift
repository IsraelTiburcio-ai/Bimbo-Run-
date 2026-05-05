import Foundation

enum OrderAction: String, Hashable {
    case replenish = "Reponer"
    case remove = "Retirar"
    case suggested = "Sugerido"
}

struct OrderItem: Identifiable, Hashable {
    var id = UUID()
    var product: Product
    var quantity: Int
    var action: OrderAction
    var note: String
    var availableInTruck: Int

    var needsTruckStock: Bool {
        action == .replenish || action == .suggested
    }

    var hasEnoughInventory: Bool {
        !needsTruckStock || quantity <= availableInTruck
    }
}
