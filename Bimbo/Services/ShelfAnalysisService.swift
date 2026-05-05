import Foundation

// MARK: - Catálogo de imágenes disponibles en Assets

enum ShelfProduct: String, CaseIterable {
    case artesano     = "Artesano"
    case bigote       = "Bigote"
    case bimbollos    = "Bimbollos"
    case bimbuñuelos  = "Bimbuñuelos"
    case gansito      = "Gansito"
    case integral     = "Integral"
    case mediasNoches = "MediasNoches"
    case panTostado   = "PanTostado"
    case panBlanco    = "PanBlanco"
    case panMolido    = "PanMolido"
    case pinguinos    = "Pinguinos"
    case canelitas    = "Canelitas"

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
    let zone: String            // "level_1"…"level_N" o "top"/"eye"/"bottom"
    let label: String
    let recommendation: String  // "urgente" | "reponer" | "ok"
    let products: [ShelfZoneProduct]
    let isNewLevel: Bool?       // la IA recomienda agregar este nivel
    let shouldRemove: Bool?     // la IA recomienda quitar este nivel
}

extension ShelfZone: Identifiable {
    var id: String { zone }
}

struct ShelfAnalysisResult: Decodable {
    let overallStatus: String   // "critico" | "atencion" | "bueno"
    let shelfZones: [ShelfZone]
    let estimatedRestock: Int
    let voiceSummary: String?   // texto listo para TTS con ElevenLabs
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

        let catalog = ShelfProduct.allCases
            .map { "  - \($0.displayName) → imageName: \"\($0.rawValue)\"" }
            .joined(separator: "\n")

        let truckStr = inventory
            .map { "\($0.product.name): \($0.available) pzs" }
            .joined(separator: " | ")

        let userPrompt = """
        Eres un asesor de anaquel Bimbo experto. Analiza la foto del anaquel de "\(store.name)".

        CATÁLOGO DE PRODUCTOS (usa el imageName EXACTO):
        \(catalog)

        INVENTARIO CAMIÓN: \(truckStr)
        MÁS VENDIDOS: \(store.bestSellers.joined(separator: ", "))
        BAJA ROTACIÓN: \(store.lowRotationProducts.joined(separator: ", "))

        INSTRUCCIONES:
        1. Detecta cuántos niveles físicos tiene el anaquel en la foto.
        2. Para cada nivel existente, recomienda qué productos van ahí y en qué cantidad.
        3. Si detectas espacio vacío suficiente para un nivel extra, agrégalo con isNewLevel:true.
        4. Si un nivel está muy vacío y no justifica existir, márcalo con shouldRemove:true.
        5. Criterios de acomodo: productos más caros/populares a nivel vista, pan grande abajo, snacks arriba.
        6. Genera un voiceSummary conciso en español (3-4 oraciones) para leer en voz alta al repartidor.

        Responde SOLO con JSON válido, sin markdown:
        {
          "overallStatus": "critico"|"atencion"|"bueno",
          "shelfZones": [
            {
              "zone": "level_1",
              "label": "Nivel 1 - Alto",
              "recommendation": "urgente"|"reponer"|"ok",
              "isNewLevel": false,
              "shouldRemove": false,
              "products": [
                {"name": "Pan Blanco", "imageName": "PanBlanco", "action": "reponer"|"ok"|"retirar", "qty": 6}
              ]
            }
          ],
          "estimatedRestock": 14,
          "voiceSummary": "El anaquel de Abarrotes Lupita requiere atención urgente. El nivel vista está prácticamente vacío y necesitas surtir Medias Noches y Gansito. Se recomienda colocar un total de 14 piezas para optimizar el espacio disponible."
        }

        Reglas:
        - Usa SOLO los imageName del catálogo, escritos exactamente igual
        - Entre 2 y 5 niveles según lo que veas en la foto
        - Máximo 3 productos por nivel
        - qty entre 1 y 12
        - voiceSummary: máximo 60 palabras, directo al repartidor, en español
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
            "max_tokens": 1000,
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
                ShelfZone(zone: "level_1", label: "Nivel 1 - Alto", recommendation: "ok",
                          products: [
                            ShelfZoneProduct(name: "Pan Blanco",  imageName: "PanBlanco",  action: "ok", qty: 0),
                            ShelfZoneProduct(name: "Pan Tostado", imageName: "PanTostado", action: "ok", qty: 0)
                          ],
                          isNewLevel: false, shouldRemove: false),
                ShelfZone(zone: "level_2", label: "Nivel 2 - Vista ⭐", recommendation: "urgente",
                          products: [
                            ShelfZoneProduct(name: "Medias Noches", imageName: "MediasNoches", action: "reponer", qty: 8),
                            ShelfZoneProduct(name: "Gansito",       imageName: "Gansito",       action: "reponer", qty: 4),
                            ShelfZoneProduct(name: "Bimbollos",     imageName: "Bimbollos",     action: "reponer", qty: 6)
                          ],
                          isNewLevel: false, shouldRemove: false),
                ShelfZone(zone: "level_3", label: "Nivel 3 - Bajo", recommendation: "reponer",
                          products: [
                            ShelfZoneProduct(name: "Canelitas", imageName: "Canelitas", action: "reponer", qty: 5),
                            ShelfZoneProduct(name: "Pingüinos", imageName: "Pinguinos", action: "reponer", qty: 4)
                          ],
                          isNewLevel: false, shouldRemove: false),
                ShelfZone(zone: "level_4", label: "Nivel 4 - Extra (nuevo)", recommendation: "ok",
                          products: [
                            ShelfZoneProduct(name: "Artesano", imageName: "Artesano", action: "reponer", qty: 4)
                          ],
                          isNewLevel: true, shouldRemove: false)
            ],
            estimatedRestock: 31,
            voiceSummary: "El anaquel de esta tienda requiere atención urgente. El nivel vista está vacío y necesitas surtir Medias Noches, Gansito y Bimbollos. Además se detectó espacio para agregar un cuarto nivel con Artesano. En total debes colocar 31 piezas."
        )
    }
}
