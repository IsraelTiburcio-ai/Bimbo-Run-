import Foundation

// MARK: - Request

struct GroqChatRequest: Encodable {
    let model: String
    let messages: [GroqMessage]
    let responseFormat: GroqResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }
}

struct GroqMessage: Codable {
    let role: String
    let content: String
}

struct GroqResponseFormat: Encodable {
    let type: String
}

// MARK: - Response

struct GroqChatResponse: Decodable {
    let choices: [GroqChoice]
}

struct GroqChoice: Decodable {
    let message: GroqMessage
}

// MARK: - AI Recommendation DTO

struct AIRecommendationDTO: Decodable {
    let productsToRemove: [RecommendedItemDTO]
    let productsToReplenish: [RecommendedItemDTO]
    let suggestedProducts: [RecommendedItemDTO]
    let layoutSuggestions: [String]
    let inventoryAlerts: [String]
}

struct RecommendedItemDTO: Decodable {
    let sku: String
    let quantity: Int
    let note: String
}
