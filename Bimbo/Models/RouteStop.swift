import Foundation

struct RouteStop: Identifiable, Hashable {
    var id = UUID()
    var storeId: UUID
    var order: Int
    var eta: String
    var distance: String
    var status: StoreStatus
    var routeNote: String
}
