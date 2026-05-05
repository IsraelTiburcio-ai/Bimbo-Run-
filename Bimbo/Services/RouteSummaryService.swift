import Foundation

struct RouteVoiceSummaryDTO: Decodable {
    let summary: String
}

final class RouteSummaryService {
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let apiKey: String

    init(apiKey: String = GroqConfig.apiKey) {
        self.apiKey = apiKey
    }

    func generateSummary(
        pendingStores: [Store],
        nextStore: Store?,
        routeStops: [RouteStop],
        inventory: [TruckInventoryItem],
        avoidedWaste: Int,
        savedMinutes: Int
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        let topInventory = inventory
            .sorted { $0.available > $1.available }
            .prefix(7)
            .map { "- \($0.product.name): \($0.available) piezas, categoria \($0.product.category)" }
            .joined(separator: "\n")

        let criticalInventory = inventory
            .filter(\.isLowStock)
            .prefix(5)
            .map { "- \($0.product.name): quedan \($0.available)" }
            .joined(separator: "\n")

        let storeContext = pendingStores
            .prefix(4)
            .map { "- \($0.name): tipo \($0.type.rawValue), vende bien \($0.bestSellers.prefix(3).joined(separator: ", ")), evitar exceso de \($0.lowRotationProducts.prefix(2).joined(separator: ", "))" }
            .joined(separator: "\n")

        let kilometers = routeStops.reduce(0.0) { $0 + $1.distanceKm }

        let prompt = """
        Genera un resumen de voz para un vendedor repartidor Bimbo antes de salir a ruta.

        Debe sonar natural, breve y accionable. NO enumeres todo el inventario.

        DATOS:
        - Tiendas pendientes: \(pendingStores.count)
        - Primera parada: \(nextStore?.name ?? "sin asignar")
        - Kilometros estimados: \(String(format: "%.1f", kilometers))
        - Minutos ahorrados acumulados: \(savedMinutes)
        - Merma evitada: \(avoidedWaste) piezas

        TIENDAS:
        \(storeContext.isEmpty ? "- Sin tiendas pendientes" : storeContext)

        INVENTARIO PRINCIPAL:
        \(topInventory)

        INVENTARIO CRITICO:
        \(criticalInventory.isEmpty ? "- Sin alertas criticas" : criticalInventory)

        REGLAS:
        - Maximo 45 palabras.
        - Español mexicano.
        - Menciona solo 2 o 3 productos importantes.
        - Da una prioridad clara para la primera tienda.
        - No digas listas largas.

        Responde SOLO JSON valido:
        {"summary":"texto para leer en voz alta"}
        """

        let body = GroqChatRequest(
            model: GroqConfig.defaultChatModel,
            messages: [
                GroqMessage(role: "system", content: "Eres copiloto de ruta Bimbo. Resume en voz para un vendedor. Responde SOLO JSON valido."),
                GroqMessage(role: "user", content: prompt)
            ],
            responseFormat: GroqResponseFormat(type: "json_object")
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? "Sin detalle del servidor"
            throw AIServiceError.httpError(statusCode: http.statusCode, message: String(bodyText.prefix(180)))
        }

        let groqResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        guard let content = groqResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AIServiceError.emptyChoices
        }

        return try JSONDecoder().decode(RouteVoiceSummaryDTO.self, from: contentData).summary
    }
}
