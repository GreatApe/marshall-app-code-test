import Foundation
import Combine

struct FiatCurrencyClient {
    let exchangeRates: ([FiatCurrency]) -> AnyPublisher<FiatExchangeRates, Never>
}

extension FiatCurrencyClient {
    static let live: Self = {
        let publisher = CurrentValueSubject<FiatExchangeRates, Never>([.usd: (1, .now), .eur: (0.9, .now), .dkk: (6.74, .now), .sek: (10.24, .now)])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        @Sendable func updateRates() {
            Task { @MainActor in
                do {
                    let (data, _) = try await URLSession.shared.data(for: .fixer(.rates))
                    let newRates = try decoder.decode(FiatExchaneRateResponse.self, from: data).newRates(base: .base)
                    publisher.value.merge(newRates) { $1 }
                } catch {
                    print("Failed to update exchange rates: \(error)")
                }
            }
        }

        updateRates()

        Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { _ in
            updateRates()
        }

        return .init(exchangeRates: { currencies in
            publisher
                .map { $0.filter { currencies.contains($0.key) } }
                .eraseToAnyPublisher()
        })
    }()

    static let mock: Self = {
        let publisher = CurrentValueSubject<FiatExchangeRates, Never>([.usd: (1, .now), .eur: (0.9, .now), .dkk: (6.5, .now), .sek: (10, .now)])

        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            let newRates = publisher.value.mapValues {
                ($0.rate * Double.random(in: 0.98...1.02), Date.now)
            }
            publisher.value.merge(newRates) { $1 }
        }

        return .init(exchangeRates: { currencies in
            publisher
                .map { $0.filter { currencies.contains($0.key) } }
                .eraseToAnyPublisher()
        })
    }()

    static let test: Self = {
        return .init(exchangeRates: { currencies in
            Just<FiatExchangeRates>([.usd: (1, .now), .dkk: (6.5, .now), .sek: (10, .now)])
                .map { $0.filter { currencies.contains($0.key) } }
                .eraseToAnyPublisher()
        })
    }()
}

struct FiatExchaneRateResponse: Decodable {
    let timestamp: Date
    let base: FiatCurrency
    let rates: [FiatCurrency.RawValue: Double]
}

extension FiatExchaneRateResponse {
    func newRates(base desiredBase: FiatCurrency) -> FiatExchangeRates {
        guard let factor = rates[desiredBase.rawValue] else { return [:] }
        let newRates = rates.compactMap { key, value -> (FiatCurrency, (rate: Double, date: Date))? in
            guard let fiat = FiatCurrency(rawValue: key) else { return nil }
            return (fiat, (value / factor, timestamp))
        }
        return Dictionary(newRates) { $1 }
    }
}

// MARK: Utilities

private extension URL {
    private static let baseURL = URL(string: "https://data.fixer.io/api/")!

    private static let apiKey: String = "7dd405b2016b406f5bbc46e7a98cc86b"

    // Interface

    static let rates = baseURL.appending(path: "latest")
        .setting(.accessKey, to: apiKey)
        .setting(.symbols, to: FiatCurrency.allCases)
}

private extension URLRequest {
    static func fixer(_ url: URL) -> Self {
        URLRequest(url: url)
    }
}

enum FiatCurrency: String, Decodable, CaseIterable {
    case usd = "USD"
    case sek = "SEK"
    case dkk = "DKK"
    case nok = "NOK"
    case yen = "YEN"
    case eur = "EUR"

    var isBase: Bool {
        self == .base
    }

    static let base: Self = .usd
}

typealias FiatExchangeRates = [FiatCurrency: (rate: Double, date: Date)]
