import Foundation
import MapKit
import UIKit

enum NavigationApp: String, CaseIterable, Identifiable {
    case waze
    case googleMaps
    case appleMaps

    var id: String { rawValue }
}

struct NavigationAppService {
    @MainActor
    func open(app: NavigationApp, latitude: Double, longitude: Double, name: String) -> String {
        switch app {
        case .waze:
            return openURL(
                appURL: URL(string: "waze://?ll=\(latitude),\(longitude)&navigate=yes"),
                webURL: URL(string: "https://waze.com/ul?ll=\(latitude),\(longitude)&navigate=yes"),
                fallbackMessage: "Waze no esta instalado. Abriendo Waze web."
            )
        case .googleMaps:
            return openURL(
                appURL: URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"),
                webURL: URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving"),
                fallbackMessage: "Google Maps no esta instalado. Abriendo Google Maps web."
            )
        case .appleMaps:
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            let item = MKMapItem(placemark: placemark)
            item.name = name
            item.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
            return "Apple Maps abierto hacia \(name)."
        }
    }

    private func openURL(appURL: URL?, webURL: URL?, fallbackMessage: String) -> String {
        guard let appURL, let webURL else {
            return "No se pudo construir la ruta de navegacion."
        }

        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
            return "Abriendo navegacion en la app instalada."
        }

        UIApplication.shared.open(webURL)
        return fallbackMessage
    }
}
