import Foundation

// MARK: - Catálogo de imágenes disponibles en Assets

enum ShelfProduct: String, CaseIterable {
    case artesano     = "Artesano"
    case bigote       = "Bigote"
    case bimbollos    = "Bimbollos"
    case bimbuñuelos  = "Bimbuñuelos"
    case barrasMultigrano = "BarrasMultigrano"
    case branFrut     = "BranFrut"
    case ceroCero     = "PanCeroCero"
    case conchas      = "Conchas"
    case donasAzucaradas = "DonasAzucaradas"
    case donasChocolate = "DonasChocolate"
    case gansito      = "Gansito"
    case hamburguesa  = "PanHamburguesa"
    case hotDog       = "PanHotDog"
    case integral     = "Integral"
    case littleBites  = "LittleBites"
    case mantechox    = "Mantechox"
    case mediasNoches = "MediasNoches"
    case miniMantecadas = "MiniMantecadas"
    case miniPanTostado = "MiniPanTostado"
    case multigrano   = "PanMultigrano"
    case panquechox   = "Panquechox"
    case panTostado   = "PanTostado"
    case panTostadoBrioche = "PanTostadoBrioche"
    case panBlanco    = "PanBlanco"
    case panMolido    = "PanMolido"
    case pinguinos    = "Pinguinos"
    case rolesCanela  = "RolesCanela"
    case canelitas    = "Canelitas"

    var displayName: String {
        switch self {
        case .artesano:     return "Artesano"
        case .bigote:       return "Bigotes"
        case .bimbollos:    return "Bimbollos"
        case .bimbuñuelos:  return "Bimbuñuelos"
        case .barrasMultigrano: return "Barras Multigrano"
        case .branFrut:     return "Barritas Bran Frut"
        case .ceroCero:     return "Pan Cero Cero"
        case .conchas:      return "Conchas de Vainilla"
        case .donasAzucaradas: return "Donas Azucaradas"
        case .donasChocolate: return "Donas con Chocolate"
        case .gansito:      return "Gansito"
        case .hamburguesa:  return "Pan Hamburguesa"
        case .hotDog:       return "Pan Hot Dog"
        case .integral:     return "Pan Integral"
        case .littleBites:  return "Little Bites"
        case .mantechox:    return "Mantechox Hershey's"
        case .mediasNoches: return "Medias Noches"
        case .miniMantecadas: return "Mini Mantecadas"
        case .miniPanTostado: return "Mini Pan Tostado"
        case .multigrano:   return "Pan Multigrano"
        case .panquechox:   return "Panquechox"
        case .panTostado:   return "Pan Tostado"
        case .panTostadoBrioche: return "Pan Tostado Brioche"
        case .panBlanco:    return "Pan Blanco"
        case .panMolido:    return "Pan Molido"
        case .pinguinos:    return "Pingüinos"
        case .rolesCanela:  return "Roles con Canela"
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
    let isShelfPhoto: Bool?
    let photoFindings: [String]?
    let detectedProducts: [String]?
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
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        let base64 = imageData.base64EncodedString()

        let catalog = ShelfProduct.allCases
            .map { "  - \($0.displayName) | imageName: \"\($0.rawValue)\"" }
            .joined(separator: "\n")

        let truckStr = inventory
            .map { "- \($0.product.name): \($0.available) pzs disponibles" }
            .joined(separator: "\n")

        let userPrompt = """
        Analiza EXCLUSIVAMENTE la imagen adjunta. No uses respuestas genéricas.

        OBJETIVO:
        Determinar si la imagen muestra un anaquel, estante o exhibidor de tienda con productos Bimbo o espacios para productos Bimbo.

        CONTEXTO DE TIENDA:
        - Tienda: \(store.name)
        - Tipo: \(store.type.rawValue)
        - Mas vendidos historicos: \(store.bestSellers.joined(separator: ", "))
        - Baja rotacion historica: \(store.lowRotationProducts.joined(separator: ", "))

        INVENTARIO DEL CAMION:
        \(truckStr)

        CATALOGO VISUAL PERMITIDO:
        \(catalog)

        INSTRUCCIONES:
        1. Primero decide si la foto SI muestra un anaquel/estante/exhibidor util para surtido. Si no lo muestra, responde isShelfPhoto:false, shelfZones:[], estimatedRestock:0 y explica en photoFindings que se debe tomar otra foto.
        2. No inventes niveles ni productos si la imagen no permite verlos.
        3. Si la foto SI muestra anaquel, describe hallazgos visuales concretos en photoFindings: numero de niveles visibles, huecos, zonas vacias, productos visibles, mala iluminacion u obstrucciones.
        4. Para cada nivel visible crea una zona. Usa SOLO productos del catalogo y SOLO si tiene sentido por huecos, historial e inventario.
        5. La recomendacion debe cambiar segun lo que se ve en la foto: si la foto tiene pocos huecos, recomienda poco; si esta vacia, recomienda mas; si no es anaquel, no recomiendes productos.
        6. No copies nombres/cantidades de ejemplos. No uses siempre los mismos productos. Personaliza con tienda, inventario, hallazgos visuales y productos detectados.
        7. qty debe ser 0 cuando action sea "ok"; entre 1 y 12 cuando action sea "reponer" o "retirar".
        8. voiceSummary debe mencionar lo que se vio en la foto, no solo historial.
        9. Inventario disponible NO significa que debas recomendar ese producto. Usalo solo como restriccion de disponibilidad.
        10. Evita recomendar Pan Blanco o Medias Noches por defecto. Solo recomiendalos si la foto muestra hueco de pan de caja/bolsa compatible, el historial lo respalda o aparecen como producto visible.
        11. Balancea por categoria segun tienda: pan de caja, bolleria, pan dulce, barras, tostados y snacks. En tienditas con compras de impulso prioriza barras/pan dulce si la foto tiene espacio pequeno; en minisuper prioriza bolleria/panes para comida si hay huecos amplios.

        Responde SOLO JSON valido con esta forma exacta:
        {
          "overallStatus": "critico|atencion|bueno|foto_invalida",
          "isShelfPhoto": true,
          "photoFindings": ["hallazgo visual concreto 1", "hallazgo visual concreto 2"],
          "detectedProducts": ["producto visible o categoria visible"],
          "shelfZones": [
            {
              "zone": "level_1",
              "label": "Nivel 1 - Alto/Vista/Bajo segun foto",
              "recommendation": "urgente|reponer|ok",
              "isNewLevel": false,
              "shouldRemove": false,
              "products": [
                {"name": "nombre del catalogo", "imageName": "imageName exacto", "action": "reponer|ok|retirar", "qty": 1}
              ]
            }
          ],
          "estimatedRestock": 0,
          "voiceSummary": "resumen breve para el repartidor"
        }

        Reglas:
        - Si no ves anaquel: no recomiendes productos.
        - Si la foto esta borrosa u obstruida: overallStatus "foto_invalida".
        - Si recomiendas reponer, respeta inventario disponible del camion.
        - Maximo 5 niveles y maximo 3 productos por nivel.
        - voiceSummary maximo 55 palabras.
        """

        let body: [String: Any] = [
            "model": GroqConfig.defaultVisionModel,
            "messages": [
                [
                    "role": "system",
                    "content": "Eres un auditor visual de anaqueles Bimbo. Debes basarte en la imagen adjunta. Si la foto no muestra anaquel, dilo y no recomiendes productos. Responde SOLO JSON valido."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                        ["type": "text", "text": userPrompt]
                    ]
                ]
            ],
            "response_format": ["type": "json_object"],
            "max_completion_tokens": 1200,
            "temperature": 0.05
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
              let jsonData = extractJSON(from: content).data(using: .utf8) else {
            throw AIServiceError.emptyChoices
        }

        let result = try JSONDecoder().decode(ShelfAnalysisResult.self, from: jsonData)
        guard result.isShelfPhoto != false || result.shelfZones.isEmpty else {
            return result
        }
        return result
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
            isShelfPhoto: true,
            photoFindings: [
                "Resultado local de respaldo, no generado por vision.",
                "Usa una foto real del anaquel para personalizar niveles y productos."
            ],
            detectedProducts: ["Pan Blanco", "Medias Noches", "Gansito"],
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
