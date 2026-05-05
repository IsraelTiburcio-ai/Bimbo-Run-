import Foundation
import MapKit

enum RouteStopStatus: String, CaseIterable, Identifiable, Hashable {
    case depot
    case pending
    case current
    case completed

    var id: String { rawValue }
}

struct RouteStop: Identifiable, Hashable {
    var id = UUID()
    var storeId: UUID?
    var order: Int
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var estimatedMinutes: Int
    var distanceKm: Double
    var eta: String
    var distance: String
    var status: RouteStopStatus
    var routeNote: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
