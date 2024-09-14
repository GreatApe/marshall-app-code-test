import Foundation
import Combine

enum FiatCurrency {
    case usd
    case sek
    case dkk
    case nok

    var isBaseCurrency: Bool {
        self == .usd
    }
}

typealias FiatExchangeRates = [FiatCurrency: (rate: Double, date: Date)]

struct FiatCurrencyClient {
    let exchangeRates: ([FiatCurrency]) -> AnyPublisher<FiatExchangeRates, Never>
}

extension FiatCurrencyClient {
    static let mock: Self = {
        let publisher = CurrentValueSubject<FiatExchangeRates, Never>([.usd: (1, .now), .dkk: (6.5, .now), .sek: (10, .now)])

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
}

extension FiatCurrency {
    var apiName: String {
        switch self {
        case .usd:
            "USD"
        case .sek:
            "SEK"
        case .dkk:
            "DKK"
        case .nok:
            "NOK"
        }
    }
}
