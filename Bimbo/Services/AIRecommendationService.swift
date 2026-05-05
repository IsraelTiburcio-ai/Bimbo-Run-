import Foundation

protocol AIRecommendationService {
    func generateRecommendation(store: Store, inventory: [TruckInventoryItem], scannedProducts: [ScannedProduct]) async throws -> ScanResult
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case networkError(underlying: Error)
    case httpError(statusCode: Int, message: String)
    case invalidResponse
    case emptyChoices

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Groq no esta configurado. Agrega GROQ_API_KEY en el Scheme o en Build Settings. Usando recomendacion local."
        case .networkError: return "Sin conexion. Usando recomendacion local."
        case .httpError(let code, let message): return "Groq respondio \(code): \(message). Usando recomendacion local."
        case .invalidResponse: return "Respuesta inesperada de la IA. Usando recomendacion local."
        case .emptyChoices: return "La IA no genero respuesta. Usando recomendacion local."
        }
    }
}
