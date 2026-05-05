import Foundation

struct Product: Identifiable, Hashable {
    var id = UUID()
    var sku: String
    var name: String
    var category: String
    var purchasePrice: Double
    var salePrice: Double
    var symbolName: String
}
