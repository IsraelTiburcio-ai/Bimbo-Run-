import Foundation

enum ExpirationRisk: String, Hashable {
    case safe
    case nearExpiration
    case expired

    var title: String {
        switch self {
        case .safe: "Vigente"
        case .nearExpiration: "Proximo a caducar"
        case .expired: "Caducado"
        }
    }
}

struct ScannedProduct: Identifiable, Hashable, Decodable {
    var id = UUID()
    let type: String
    let sku: String
    let name: String
    let batch: String
    let expiresAt: Date
    let quantity: Int
    let buyPrice: Double
    let sellPrice: Double
    let rawPayload: String

    enum CodingKeys: String, CodingKey {
        case type, sku, name, batch, expiresAt, quantity, buyPrice, sellPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        sku = try container.decode(String.self, forKey: .sku)
        name = try container.decode(String.self, forKey: .name)
        batch = try container.decode(String.self, forKey: .batch)
        quantity = try container.decode(Int.self, forKey: .quantity)
        buyPrice = try container.decode(Double.self, forKey: .buyPrice)
        sellPrice = try container.decode(Double.self, forKey: .sellPrice)
        rawPayload = ""

        let dateText = try container.decode(String.self, forKey: .expiresAt)
        guard let date = Self.dateFormatter.date(from: dateText) else {
            throw DecodingError.dataCorruptedError(
                forKey: .expiresAt,
                in: container,
                debugDescription: "Fecha esperada en formato yyyy-MM-dd"
            )
        }
        expiresAt = date
    }

    init(decoded product: ScannedProduct, rawPayload: String) {
        self.type = product.type
        self.sku = product.sku
        self.name = product.name
        self.batch = product.batch
        self.expiresAt = product.expiresAt
        self.quantity = product.quantity
        self.buyPrice = product.buyPrice
        self.sellPrice = product.sellPrice
        self.rawPayload = rawPayload
    }

    var expirationRisk: ExpirationRisk {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDay = calendar.startOfDay(for: expiresAt)
        let days = calendar.dateComponents([.day], from: today, to: expirationDay).day ?? 0

        if days < 0 {
            return .expired
        }
        if days <= 14 {
            return .nearExpiration
        }
        return .safe
    }

    var daysToExpire: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiresAt)
        ).day ?? 0
    }

    static func parse(_ payload: String) throws -> ScannedProduct {
        let data = Data(payload.utf8)
        let decoder = JSONDecoder()
        let product = try decoder.decode(ScannedProduct.self, from: data)
        guard product.type == "product" else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "QR no es de producto"))
        }
        return ScannedProduct(decoded: product, rawPayload: payload)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
