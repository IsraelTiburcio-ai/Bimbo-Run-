import Foundation

struct RouteStore: Identifiable, Hashable {
    let id = UUID()
    var routeName: String
    var sellerName: String
    var plannedStores: Int
    var startedAt: Date
}
