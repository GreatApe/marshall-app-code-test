import Combine
import Foundation

typealias CoinID = Int

struct CoinPriceClient {
    let listedCoins: () async throws -> [CoinPriceData]
    let latestPrices: ([CoinID]) async throws -> [CoinID: CoinPriceData]
}

struct CoinPriceData: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let quote: [String: CoinPriceQuote]

    var quoteUSD: CoinPriceQuote? {
        quote[FiatCurrency.usd.apiName]
    }
}

struct CoinPriceQuote: Decodable {
    let price: Double
    let volume24h: Double
    let marketCap: Double
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case price = "price"
        case volume24h = "volume_24h"
        case marketCap = "market_cap"
        case lastUpdated = "last_updated"
    }
}

extension CoinPriceClient {
    static let live: Self = {
        .init(
            listedCoins: {
                let (data, _) = try await URLSession.shared.data(for: .listedCoins())
                return try JSONDecoder.isoDecoder.decode(ListedCoinsResponse.self, from: data).data
            },
            latestPrices: { ids in
                let (data, _) = try await URLSession.shared.data(for: .latestcoinPrices(ids))
                return try JSONDecoder.isoDecoder.decode(LatestPricesResponse.self, from: data).data
            }
        )
    }()
}

private struct ListedCoinsResponse: Decodable {
    let data: [CoinPriceData]
}

private struct LatestPricesResponse: Decodable {
    let data: [CoinID: CoinPriceData]
}

// MARK: Utilities

private extension URLRequest {
    private static let apiKey: String = "e3ef21f0-63cb-4979-87a7-0b03713e91bd"

    private static let listingsURL = URL(string: "https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest")!

    private static let latestPricesURL = URL(string: "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest")!

    static func listedCoins() -> Self {
        URLRequest(url: listingsURL)
            .withHeaders
    }

    static func latestcoinPrices(_ ids: [CoinID]) -> Self {
        URLRequest(url: latestPricesURL.withIDs(ids))
            .withHeaders
    }

    private var withHeaders: Self {
        var request = self
        request.setValue("application/json", forHTTPHeaderField: "Accepts")
        request.setValue(Self.apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        return request
    }
}

private extension URL {
    func withIDs(_ ids: [CoinID]) -> URL {
        var url = self
        url.append(
            queryItems: [
                .init(name: "id", value: ids.map(String.init).joined(separator: ",")),
            ]
        )

        return url
    }
}

private extension JSONDecoder {
    static let isoDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}
