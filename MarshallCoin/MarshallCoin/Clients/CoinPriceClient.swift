import Combine
import Foundation

typealias CoinID = Int
typealias ValuePublisher<T> = AnyPublisher<T, Never>

struct CoinPriceClient {
    let listedCoins: () async throws -> [CoinPriceData]
    let prices: (ValuePublisher<[CoinID]>) -> ValuePublisher<[CoinID: CoinPriceData]>
    let priceHistory: (CoinID) async throws -> [DatedQuote]
}

extension CoinPriceClient {
    static let live: Self = {
        func pricePublisher(ids: [CoinID]) -> ValuePublisher<[CoinID: CoinPriceData]> {
            URLSession.shared.dataTaskPublisher(for: .cmc(.latestPrices(for: ids)))
                .tryMap { try JSONDecoder.isoDecoder.decode(LatestPricesResponse.self, from: $0.data).data }
                .replaceError(with: [:])
                .eraseToAnyPublisher()
        }

        return .init(
            listedCoins: {
                let (data, _) = try await URLSession.shared.data(for: .cmc(.listings))
                return try JSONDecoder.isoDecoder.decode(ListedCoinsResponse.self, from: data).data
            },
            prices: { ids in
                Timer.publish(every: 10, on: .main, in: .default)
                    .autoconnect()
                    .combineLatest(ids)
                    .flatMap { pricePublisher(ids: $1) }
                    .eraseToAnyPublisher()
            },
            priceHistory: { id in
                let (data, _) = try await URLSession.shared.data(for: .cmc(.priceHistory(.daily, for: id, count: 30)))
                return try JSONDecoder.isoDecoder.decode(PriceHistoryResponse.self, from: data).data.quotesUSD
            }
        )
    }()

    static let mock: Self = {
        return .init(
            listedCoins: {
                [.random(id: 1), .random(id: 2), .random(id: 3)]
            },
            prices: { ids in
                ids.map { idValues in
                    Dictionary(idValues.map { ($0, CoinPriceData.random(id: $0)) }) { $1 }
                }
                .eraseToAnyPublisher()
            },
            priceHistory: { _ in
                .random()
            }
        )
    }()

    static let test: Self = {
        return .init(
            listedCoins: {
                [.testValue(id: 1), .testValue(id: 2)]
            },
            prices: { ids in
                ids.map { idValues in
                    Dictionary(idValues.map { ($0, CoinPriceData.testValue(id: $0)) }) { $1 }
                }
                .eraseToAnyPublisher()
            },
            priceHistory: { _ in
                .testValue
            }
        )
    }()
}

struct CoinPriceData: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let quote: [FiatCurrency.RawValue: CoinPriceQuote]

    var quoteUSD: CoinPriceQuote? {
        quote[FiatCurrency.usd.rawValue]
    }
}

struct CoinPriceHistoryData: Decodable {
    let quotes: [Quote]

    var quotesUSD: [DatedQuote] {
        quotes.compactMap { $0.quote[FiatCurrency.usd.rawValue] }
    }

    struct Quote: Decodable {
        let quote: [FiatCurrency.RawValue: DatedQuote]
    }
}

struct DatedQuote: Decodable {
    let timestamp: Date
    let price: Double
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

private struct ListedCoinsResponse: Decodable {
    let data: [CoinPriceData]
}

private struct LatestPricesResponse: Decodable {
    let data: [CoinID: CoinPriceData]
}

private struct PriceHistoryResponse: Decodable {
    let data: CoinPriceHistoryData
}

// MARK: Utilities

private extension URLRequest {
    private static let apiKey: String = "e3ef21f0-63cb-4979-87a7-0b03713e91bd"

    static func cmc(_ url: URL) -> Self {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accepts")
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        return request
    }
}

enum PriceHistoryInterval: String {
    case hourly
    case daily

    case every5m = "5m"
    case every10m = "10m"
    case every30m = "30m"
    case every1h = "1h"
    case every6h = "6h"
    case every12h = "12h"
}

private extension URL {
    private static let baseURL = URL(string: "https://pro-api.coinmarketcap.com")!

    // Interface

    static let listings = baseURL.appending(path: "v1/cryptocurrency/listings/latest")

    static func latestPrices(for ids: [CoinID]) -> Self {
        baseURL
            .appending(path: "v2/cryptocurrency/quotes/latest")
            .setting(.id, to: ids)
    }

    static func priceHistory(_ interval: PriceHistoryInterval, for id: CoinID, count: Int) -> Self {
        baseURL
            .appending(path: "v2/cryptocurrency/quotes/historical")
            .setting(.id, to: id)
            .setting(.interval, to: interval)
            .setting(.count, to: count)
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

// MARK: General utilities

extension URL {
    enum Item: String {
        case id
        case count
        case interval
        case accessKey = "access_key"
        case base
        case symbols
    }

    func setting(_ item: Item, to value: ItemValue) -> URL {
        var url = self
        url.append(
            queryItems: [
                .init(name: item.rawValue, value: value.asValue),
            ]
        )
        return url
    }
}

protocol ItemValue {
    var asValue: String { get }
}

extension Int: ItemValue {
    var asValue: String { String(self) }
}

extension String: ItemValue {
    var asValue: String { self }
}

extension PriceHistoryInterval: ItemValue { }

extension FiatCurrency: ItemValue { }

extension Array: ItemValue where Element: ItemValue {
    var asValue: String { self.map(\.asValue).joined(separator: ",") }
}

extension RawRepresentable where RawValue == String {
    var asValue: String { rawValue }
}

// MARK: Testing and mocking

private extension CoinPriceData {
    static func random(id: CoinID) -> Self {
        CoinPriceData(
            id: id,
            name: "SuperCoin\(id)",
            symbol: "CN\(id)",
            quote: ["USD": .init(
                price: 60000.randomCloseBy(),
                volume24h: 10000.randomCloseBy(),
                marketCap: 10000000.randomCloseBy(),
                lastUpdated: .now
            )]
        )
    }

    static func testValue(id: CoinID) -> Self {
        CoinPriceData(
            id: id,
            name: "SuperCoin\(id)",
            symbol: "CN\(id)",
            quote: ["USD": .init(
                price: 60000 * Double(id),
                volume24h: 10000 * Double(id),
                marketCap: 10000000 * Double(id),
                lastUpdated: .init(timeIntervalSince1970: 1000000 + 100000 * Double(id))
            )]
        )
    }
}

private extension [DatedQuote] {
    static func random() -> Self {
        var timestamp: Date = .now
        var price: Double = 100
        var result: [DatedQuote] = []
        for _ in 0..<50 {
            price = price * 1.randomCloseBy()
            timestamp = timestamp.addingTimeInterval(60 * 60)
            result.append(.init(timestamp: timestamp, price: price))
        }
        return result
    }

    static let testValue: Self = (0...100).map { i in
        .init(
            timestamp: .init(timeIntervalSince1970: 1000000 + Double(i) * 3600),
            price: 100 + Double(i)
        )
    }
}

private extension Double {
    func randomCloseBy() -> Double {
        self * .random(in: 0.97...1.03)
    }
}
