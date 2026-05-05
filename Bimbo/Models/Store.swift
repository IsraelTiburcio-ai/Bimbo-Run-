import Foundation
import SwiftUI

enum StoreStatus: String, CaseIterable, Identifiable, Hashable {
    case pending
    case inProgress
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pendiente"
        case .inProgress: "En tienda"
        case .completed: "Completada"
        }
    }

    var tint: Color {
        switch self {
        case .pending: AppTheme.warning
        case .inProgress: AppTheme.electricBlue
        case .completed: AppTheme.success
        }
    }
}

enum StoreType: String, CaseIterable, Identifiable, Hashable {
    case tiendita = "Tiendita"
    case abarrotes = "Abarrotes"
    case minisuper = "Minisuper"
    case expendio = "Expendio"
    case otro = "Otro"

    var id: String { rawValue }
}

enum VisitFrequency: String, CaseIterable, Identifiable, Hashable {
    case weekly = "1 vez por semana"
    case twiceWeekly = "2 veces por semana"

    var id: String { rawValue }
}

struct Store: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var clientId: String
    var contactName: String
    var phone: String
    var address: String
    var reference: String
    var type: StoreType
    var visitFrequency: VisitFrequency
    var status: StoreStatus
    var aiHint: String
    var lastVisit: String
    var lastReturn: String
    var estimatedBudget: Double
    var bestSellers: [String]
    var lowRotationProducts: [String]
    var lastDeliveredProducts: [OrderItem]
    var visitHistory: [String]
    var isNewPendingValidation: Bool = false

    var bestSeller: String { bestSellers.first ?? "Por aprender" }
    var lowRotationProduct: String { lowRotationProducts.first ?? "Por aprender" }
}
