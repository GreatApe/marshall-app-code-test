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
            let newSekRate: FiatExchangeRates = [
                .sek: (Double.random(in: 9...11), .now),
                .dkk: (Double.random(in: 6...7), .now),
                .nok: (Double.random(in: 9...11), .now)
            ]
            publisher.value.merge(newSekRate) { $1 }
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
