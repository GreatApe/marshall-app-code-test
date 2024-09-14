import Combine
import Foundation

typealias CoinSymbol = String

struct CoinPriceClient {
    let coinPrices: ([CoinSymbol]?) async throws -> [CoinSymbol: CoinPriceData]
}

struct CoinPriceResponse: Decodable {
    let data: [CoinPriceData]
}

struct CoinPriceData: Decodable {
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
    private static var apiKey: String { "e3ef21f0-63cb-4979-87a7-0b03713e91bd" }

    private static var coinsURL: URL { URL(string: "https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest")! }

    private static func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accepts")
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        return request
    }

    static let live: Self = {
        return .init(
            coinPrices: { symbols in
                let url = CoinPriceClient.coinsURL
                let (data, _) = try await URLSession.shared.data(for: CoinPriceClient.request(url: url))
                let priceData = try JSONDecoder.isoDecoder.decode(CoinPriceResponse.self, from: data).data
                var result: [CoinSymbol: CoinPriceData] = [:]
                for priceDatum in priceData {
                    result[priceDatum.symbol] = priceDatum
                }
                return result
            }
        )
    }()

    //        url.append(
    //            queryItems: [
    //                .init(name: "start", value: "1"),
    //                .init(name: "limit", value: "100"),
    //                .init(name: "convert", value: "USD")
    //            ]
    //        )
}

// MARK: Utilities

extension URLRequest {
    private static let apiKey: String = "e3ef21f0-63cb-4979-87a7-0b03713e91bd"

    private static let coinsURL = URL(string: "https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest")!

    static func coinPrices(_ symbols: [CoinSymbol]? = nil) {
        
    }


    private static func requestWithHeaders(for url: URL) -> Self {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accepts")
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        return request
    }

}

extension JSONDecoder {
    static let isoDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}
