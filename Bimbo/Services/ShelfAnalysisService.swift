import Foundation

// MARK: - Response Models

struct ShelfZoneProduct: Decodable {
    let name: String
    let action: String  // "reponer" | "ok" | "retirar"
    let qty: Int
    let sku: String
}

extension ShelfZoneProduct: Identifiable {
    var id: String { sku + action }
}

struct ShelfZone: Decodable {
    let zone: String            // "top" | "eye" | "bottom"
    let label: String
    let recommendation: String  // "urgente" | "reponer" | "ok"
    let products: [ShelfZoneProduct]
}

extension ShelfZone: Identifiable {
    var id: String { zone }
}

struct ShelfTopAction: Decodable {
    let type: String      // "subir" | "reponer" | "retirar" | "revisar"
    let text: String
    let priority: String  // "alta" | "media" | "baja"
}

extension ShelfTopAction: Identifiable {
    var id: String { text }
}

struct ShelfAnalysisResult: Decodable {
    let overallStatus: String   // "critico" | "atencion" | "bueno"
    let shelfZones: [ShelfZone]
    let topActions: [ShelfTopAction]
    let estimatedRestock: Int
}

// MARK: - Service

final class ShelfAnalysisService {
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let apiKey: String

    init(apiKey: String = GroqConfig.apiKey) {
        self.apiKey = apiKey
    }

    func analyzeShelf(imageData: Data, store: Store, inventory: [TruckInventoryItem]) async throws -> ShelfAnalysisResult {
        guard !apiKey.isEmpty else { return mockResult(for: store) }

        let base64 = imageData.base64EncodedString()
        let skus = inventory.map(\.product.sku).joined(separator: ", ")
        let availableStr = inventory.map { "\($0.product.name): \($0.available) pzs" }.joined(separator: " | ")

        let userPrompt = """
        Analiza la foto del anaquel de la tienda "\(store.name)".
        Camión disponible: \(availableStr)
        Más vendidos: \(store.bestSellers.joined(separator: ", "))
        Baja rotación: \(store.lowRotationProducts.joined(separator: ", "))
        SKUs válidos: \(skus)

        Responde SOLO con JSON válido sin markdown:
        {
          "overallStatus": "critico"|"atencion"|"bueno",
          "shelfZones": [
            {"zone":"top","label":"Nivel alto","recommendation":"urgente"|"reponer"|"ok","products":[{"name":"...","action":"reponer"|"ok"|"retirar","qty":5,"sku":"..."}]},
            {"zone":"eye","label":"Nivel vista","recommendation":"urgente"|"reponer"|"ok","products":[...]},
            {"zone":"bottom","label":"Nivel bajo","recommendation":"urgente"|"reponer"|"ok","products":[...]}
          ],
          "topActions": [
            {"type":"subir"|"reponer"|"retirar"|"revisar","text":"acción breve máx 5 palabras","priority":"alta"|"media"|"baja"}
          ],
          "estimatedRestock": 14
        }
        Máximo 2 productos por zona. Máximo 3 acciones. Usa solo los SKUs proporcionados.
        """

        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [
                ["role": "system", "content": "Eres un asesor de anaquel Bimbo. Responde SOLO con JSON válido, sin texto adicional, sin markdown."],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                    ["type": "text", "text": userPrompt]
                ]]
            ],
            "max_tokens": 800,
            "temperature": 0.2
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIServiceError.invalidResponse
        }

        let groqResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        guard let content = groqResponse.choices.first?.message.content,
              let jsonData = extractJSON(from: content).data(using: .utf8) else {
            throw AIServiceError.emptyChoices
        }

        return try JSONDecoder().decode(ShelfAnalysisResult.self, from: jsonData)
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        if let s = text.range(of: "```json\n"), let e = text.range(of: "```", range: s.upperBound..<text.endIndex) {
            return String(text[s.upperBound..<e.lowerBound])
        }
        if let s = text.range(of: "```\n"), let e = text.range(of: "```", range: s.upperBound..<text.endIndex) {
            return String(text[s.upperBound..<e.lowerBound])
        }
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
            return String(text[s...e])
        }
        return text
    }

    // Mock para cuando no hay API key configurada
    func mockResult(for store: Store) -> ShelfAnalysisResult {
        ShelfAnalysisResult(
            overallStatus: "atencion",
            shelfZones: [
                ShelfZone(zone: "top", label: "Nivel alto", recommendation: "ok",
                          products: [ShelfZoneProduct(name: "Pan Blanco", action: "ok", qty: 0, sku: "PAN-BLANCO")]),
                ShelfZone(zone: "eye", label: "Nivel vista", recommendation: "urgente",
                          products: [
                            ShelfZoneProduct(name: "Medias Noches", action: "reponer", qty: 8, sku: "MEDIAS-NOCHES"),
                            ShelfZoneProduct(name: "Gansito", action: "reponer", qty: 4, sku: "GANSITO")
                          ]),
                ShelfZone(zone: "bottom", label: "Nivel bajo", recommendation: "reponer",
                          products: [ShelfZoneProduct(name: "Takis", action: "reponer", qty: 6, sku: "TAKIS")])
            ],
            topActions: [
                ShelfTopAction(type: "reponer", text: "Surtir Medias Noches nivel vista", priority: "alta"),
                ShelfTopAction(type: "subir", text: "Subir Takis a nivel mano", priority: "media"),
                ShelfTopAction(type: "revisar", text: "Verificar fechas Pan Blanco", priority: "baja")
            ],
            estimatedRestock: 18
        )
    }
}
