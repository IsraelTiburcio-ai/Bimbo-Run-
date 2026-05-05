import Foundation

struct ProductRecommendation: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: Int
    var note: String
}
