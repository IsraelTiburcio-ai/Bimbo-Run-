import Foundation

protocol AIRecommendationService {
    func generateRecommendation(store: Store, inventory: [TruckInventoryItem]) async throws -> ScanResult
}

enum AIServiceError: LocalizedError {
    case networkError(underlying: Error)
    case httpError(statusCode: Int)
    case invalidResponse
    case emptyChoices

    var errorDescription: String? {
        switch self {
        case .networkError: return "Sin conexion. Usando recomendacion local."
        case .httpError(let code): return "Error del servidor (\(code)). Usando recomendacion local."
        case .invalidResponse: return "Respuesta inesperada de la IA. Usando recomendacion local."
        case .emptyChoices: return "La IA no genero respuesta. Usando recomendacion local."
        }
    }
}
