import Foundation

struct ScanResult: Identifiable, Hashable {
    var id = UUID()
    var storeId: UUID?
    var productsToRemove: [OrderItem]
    var productsToReplenish: [OrderItem]
    var suggestedProducts: [OrderItem]
    var layoutSuggestions: [String]
    var inventoryAlerts: [String]
}
