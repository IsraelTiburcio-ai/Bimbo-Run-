import Foundation

// MARK: - Catálogo de imágenes disponibles en Assets

enum ShelfProduct: String, CaseIterable {
    case artesano      = "Artesano"
    case bigote        = "Bigote"
    case bimbollos     = "Bimbollos"
    case bimbuñuelos   = "Bimbuñuelos"
    case gansito       = "Gansito"
    case integral      = "Integral"
    case mediasNoches  = "MediasNoches"
    case panTostado    = "PanTostado"
    case panBlanco     = "PanBlanco"
    case panMolido     = "PanMolido"
    case pinguinos     = "Pinguinos"
    case canelitas     = "Canelitas"

    var displayName: String {
        switch self {
        case .artesano:     return "Artesano"
        case .bigote:       return "Bigotes"
        case .bimbollos:    return "Bimbollos"
        case .bimbuñuelos:  return "Bimbuñuelos"
        case .gansito:      return "Gansito"
        case .integral:     return "Pan Integral"
        case .mediasNoches: return "Medias Noches"
        case .panTostado:   return "Pan Tostado"
        case .panBlanco:    return "Pan Blanco"
        case .panMolido:    return "Pan Molido"
        case .pinguinos:    return "Pingüinos"
        case .canelitas:    return "Canelitas"
        }
    }
}

// MARK: - Response Models

struct ShelfZoneProduct: Decodable {
    let name: String
    let imageName: String  // coincide exactamente con el nombre del asset
    let action: String     // "reponer" | "ok" | "retirar"
    let qty: Int
}

extension ShelfZoneProduct: Identifiable {
    var id: String { imageName + action }
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

struct ShelfAnalysisResult: Decodable {
    let overallStatus: String  // "critico" | "atencion" | "bueno"
    let shelfZones: [ShelfZone]
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
        guard !apiKey.isEmpty else { return mockResult() }

        let base64 = imageData.base64EncodedString()

        // Catálogo completo de productos con su imageName exacto
        let catalog = ShelfProduct.allCases
            .map { "  - \($0.displayName) → imageName: \"\($0.rawValue)\"" }
            .joined(separator: "\n")

        // Qué hay disponible en el camión (cruzado con el catálogo)
        let truckStr = inventory
            .map { "\($0.product.name): \($0.available) pzs" }
            .joined(separator: " | ")

        let userPrompt = """
        Analiza la foto del anaquel de la tienda "\(store.name)".

        CATÁLOGO DE PRODUCTOS BIMBO (usa el imageName EXACTO en tu respuesta):
        \(catalog)

        INVENTARIO DISPONIBLE EN CAMIÓN: \(truckStr)
        MÁS VENDIDOS EN ESTA TIENDA: \(store.bestSellers.joined(separator: ", "))
        BAJA ROTACIÓN: \(store.lowRotationProducts.joined(separator: ", "))

        Observa la foto: detecta los espacios vacíos o con poco producto en el anaquel.
        Recomienda qué productos del catálogo colocar en cada nivel para optimizar ventas.

        Responde SOLO con JSON válido, sin markdown, sin texto extra:
        {
          "overallStatus": "critico"|"atencion"|"bueno",
          "shelfZones": [
            {
              "zone": "top",
              "label": "Nivel alto",
              "recommendation": "urgente"|"reponer"|"ok",
              "products": [
                {"name": "Pan Blanco", "imageName": "PanBlanco", "action": "reponer"|"ok"|"retirar", "qty": 6}
              ]
            },
            {
              "zone": "eye",
              "label": "Nivel vista",
              "recommendation": "urgente"|"reponer"|"ok",
              "products": [...]
            },
            {
              "zone": "bottom",
              "label": "Nivel bajo",
              "recommendation": "urgente"|"reponer"|"ok",
              "products": [...]
            }
          ],
          "estimatedRestock": 14
        }

        Reglas:
        - Usa SOLO los imageName del catálogo proporcionado, escritos exactamente igual
        - Máximo 3 productos por zona
        - qty debe ser entre 1 y 12
        - Prioriza los más vendidos en nivel vista (eye)
        - Si el anaquel se ve bien en una zona, usa recommendation "ok" y products vacío []
        """

        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [
                [
                    "role": "system",
                    "content": "Eres un asesor de anaquel Bimbo experto. Responde SOLO con JSON válido, sin texto adicional, sin markdown."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                        ["type": "text", "text": userPrompt]
                    ]
                ]
            ],
            "max_tokens": 900,
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

    func mockResult() -> ShelfAnalysisResult {
        ShelfAnalysisResult(
            overallStatus: "atencion",
            shelfZones: [
                ShelfZone(zone: "top", label: "Nivel alto", recommendation: "ok",
                          products: [
                            ShelfZoneProduct(name: "Pan Blanco", imageName: "PanBlanco", action: "ok", qty: 0),
                            ShelfZoneProduct(name: "Pan Tostado", imageName: "PanTostado", action: "ok", qty: 0)
                          ]),
                ShelfZone(zone: "eye", label: "Nivel vista", recommendation: "urgente",
                          products: [
                            ShelfZoneProduct(name: "Medias Noches", imageName: "MediasNoches", action: "reponer", qty: 8),
                            ShelfZoneProduct(name: "Gansito", imageName: "Gansito", action: "reponer", qty: 4),
                            ShelfZoneProduct(name: "Bimbollos", imageName: "Bimbollos", action: "reponer", qty: 6)
                          ]),
                ShelfZone(zone: "bottom", label: "Nivel bajo", recommendation: "reponer",
                          products: [
                            ShelfZoneProduct(name: "Canelitas", imageName: "Canelitas", action: "reponer", qty: 5),
                            ShelfZoneProduct(name: "Pingüinos", imageName: "Pinguinos", action: "reponer", qty: 4)
                          ])
            ],
            estimatedRestock: 27
        )
    }
}
