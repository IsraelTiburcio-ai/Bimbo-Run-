import Foundation

struct TruckInventoryItem: Identifiable, Hashable {
    var id = UUID()
    var product: Product
    var available: Int
    var reservedSuggested: Int
    var returned: Int
    var lowStockThreshold: Int

    var isLowStock: Bool {
        available <= lowStockThreshold
    }
}
