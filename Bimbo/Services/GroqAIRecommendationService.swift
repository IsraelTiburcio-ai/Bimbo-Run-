import Foundation

final class GroqAIRecommendationService: AIRecommendationService {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(apiKey: String = GroqConfig.apiKey) {
        self.apiKey = apiKey
    }

    func generateRecommendation(store: Store, inventory: [TruckInventoryItem], scannedProducts: [ScannedProduct]) async throws -> ScanResult {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        let dto = try await callGroq(prompt: buildPrompt(store: store, inventory: inventory, scannedProducts: scannedProducts))
        return map(dto: dto, storeId: store.id, inventory: inventory)
    }

    // MARK: - Private

    private func buildPrompt(store: Store, inventory: [TruckInventoryItem], scannedProducts: [ScannedProduct]) -> String {
        let validSKUs = inventory.map { $0.product.sku }.joined(separator: ", ")
        let inventoryLines = inventory.map {
            "  - SKU: \($0.product.sku) | Nombre: \($0.product.name) | Disponible: \($0.available) pzs | Bajo stock: \($0.isLowStock ? "SI" : "NO")"
        }.joined(separator: "\n")
        let scannedLines = scannedProducts.isEmpty
            ? "  - Sin productos escaneados aun."
            : scannedProducts.map {
                "  - SKU: \($0.sku) | Nombre: \($0.name) | Lote: \($0.batch) | Caduca: \(ScannedProduct.dateFormatter.string(from: $0.expiresAt)) | Riesgo: \($0.expirationRisk.title) | Cantidad: \($0.quantity)"
            }.joined(separator: "\n")

        return """
        Analiza el contexto de esta tienda, el inventario del camion y los productos escaneados en anaquel. Genera una recomendacion de surtido para el vendedor de campo.

        TIENDA:
        - Nombre: \(store.name)
        - Tipo: \(store.type.rawValue)
        - Mas vendidos: \(store.bestSellers.joined(separator: ", "))
        - Baja rotacion: \(store.lowRotationProducts.joined(separator: ", "))
        - Ultima visita: \(store.lastVisit)
        - Ultima devolucion: \(store.lastReturn)
        - Presupuesto estimado: $\(Int(store.estimatedBudget))
        - Historial reciente: \(store.visitHistory.prefix(2).joined(separator: " | "))

        INVENTARIO DEL CAMION:
        \(inventoryLines)

        PRODUCTOS ESCANEADOS EN TIEMPO REAL:
        \(scannedLines)

        REGLAS:
        - Usa solo los siguientes SKUs: \(validSKUs)
        - No inventes SKUs ni nombres de productos
        - Cantidades razonables: entre 1 y 15 piezas por producto
        - productsToRemove: prioriza productos caducados o proximos a caducar detectados por QR
        - productsToReplenish: productos con alta rotacion o frente incompleto
        - suggestedProducts: productos adicionales segun el tipo de tienda
        - inventoryAlerts: solo si hay stock insuficiente para lo recomendado
        - Notas en espanol, breves y utiles para el vendedor

        Responde SOLO con JSON valido usando exactamente esta estructura:
        {
          "productsToRemove": [{"sku": "SKU", "quantity": 1, "note": "razon breve"}],
          "productsToReplenish": [{"sku": "SKU", "quantity": 8, "note": "razon breve"}],
          "suggestedProducts": [{"sku": "SKU", "quantity": 6, "note": "razon breve"}],
          "layoutSuggestions": ["sugerencia 1", "sugerencia 2"],
          "inventoryAlerts": []
        }
        """
    }

    private func callGroq(prompt: String) async throws -> AIRecommendationDTO {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GroqChatRequest(
            model: "llama-3.3-70b-versatile",
            messages: [
                GroqMessage(role: "system", content: "Eres un asistente de ventas de campo para Bimbo. Responde SOLO con JSON valido, sin texto adicional, sin markdown."),
                GroqMessage(role: "user", content: prompt)
            ],
            responseFormat: GroqResponseFormat(type: "json_object")
        )

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw AIServiceError.invalidResponse
        }

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
            throw AIServiceError.httpError(statusCode: http.statusCode)
        }

        let groqResponse: GroqChatResponse
        do {
            groqResponse = try decoder.decode(GroqChatResponse.self, from: data)
        } catch {
            throw AIServiceError.invalidResponse
        }

        guard let content = groqResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AIServiceError.emptyChoices
        }

        do {
            return try decoder.decode(AIRecommendationDTO.self, from: contentData)
        } catch {
            throw AIServiceError.invalidResponse
        }
    }

    private func map(dto: AIRecommendationDTO, storeId: UUID, inventory: [TruckInventoryItem]) -> ScanResult {
        func orderItem(from itemDTO: RecommendedItemDTO, action: OrderAction) -> OrderItem? {
            guard let product = Product.mockProducts.first(where: { $0.sku == itemDTO.sku }) else { return nil }
            let available = inventory.first(where: { $0.product.sku == itemDTO.sku })?.available ?? 0
            return OrderItem(product: product, quantity: itemDTO.quantity, action: action, note: itemDTO.note, availableInTruck: available)
        }

        let remove = dto.productsToRemove.compactMap { orderItem(from: $0, action: .remove) }
        let replenish = dto.productsToReplenish.compactMap { orderItem(from: $0, action: .replenish) }
        let suggested = dto.suggestedProducts.compactMap { orderItem(from: $0, action: .suggested) }

        var alerts = dto.inventoryAlerts
        alerts += (replenish + suggested)
            .filter { !$0.hasEnoughInventory }
            .map { "Inventario insuficiente para \($0.product.name): hay \($0.availableInTruck), se sugieren \($0.quantity)." }

        return ScanResult(
            storeId: storeId,
            productsToRemove: remove,
            productsToReplenish: replenish,
            suggestedProducts: suggested,
            layoutSuggestions: dto.layoutSuggestions,
            inventoryAlerts: alerts
        )
    }
}
