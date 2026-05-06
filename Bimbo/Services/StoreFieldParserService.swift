import Foundation

// MARK: - Parsed fields from voice transcript

struct ParsedStoreFields: Decodable {
    let estimatedBudget: Double?
    let bestSellers: [String]?
    let lowRotationProducts: [String]?
    let lastVisit: String?
    let lastReturn: String?
}

// MARK: - Groq-based parser

final class StoreFieldParserService {
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let apiKey: String

    init(apiKey: String = GroqConfig.apiKey) {
        self.apiKey = apiKey
    }

    func parse(transcript: String, storeName: String) async throws -> ParsedStoreFields {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        let prompt = """
        El repartidor Bimbo está en la tienda "\(storeName)" y dijo lo siguiente al llegar:
        "\(transcript)"

        Extrae la información de la visita. Responde SOLO con JSON válido:
        {
          "estimatedBudget": número o null,
          "bestSellers": ["producto1", "producto2"] o [],
          "lowRotationProducts": ["producto1"] o [],
          "lastVisit": "texto de cuándo fue la última visita" o null,
          "lastReturn": "descripción de devoluciones" o null
        }

        Reglas:
        - estimatedBudget: solo número sin símbolo de moneda (ej: 1500.0)
        - bestSellers: productos que se venden bien según dijo el cliente
        - lowRotationProducts: productos que no rotan o tienen baja venta
        - lastVisit: texto libre (ej: "Hoy, 10:30 AM", "Hace 3 días", etc.)
        - lastReturn: descripción de piezas a devolver (ej: "3 piezas de Gansito")
        - Si no se mencionó algo, devuelve null para ese campo
        """

        let body = GroqChatRequest(
            model: GroqConfig.defaultChatModel,
            messages: [
                GroqMessage(role: "system", content: "Eres un asistente de ventas Bimbo. Extrae información de visita del texto. Responde SOLO con JSON válido."),
                GroqMessage(role: "user", content: prompt)
            ],
            responseFormat: GroqResponseFormat(type: "json_object")
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIServiceError.invalidResponse
        }

        let groqResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)
        guard let content = groqResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AIServiceError.emptyChoices
        }

        return try JSONDecoder().decode(ParsedStoreFields.self, from: contentData)
    }

    // Fallback para cuando no hay API key
    func mockParsed() -> ParsedStoreFields {
        ParsedStoreFields(
            estimatedBudget: 1800,
            bestSellers: ["Medias Noches", "Pan Blanco"],
            lowRotationProducts: ["Gansito"],
            lastVisit: "Hoy, 10:30 AM",
            lastReturn: "2 piezas de Gansito"
        )
    }
}
