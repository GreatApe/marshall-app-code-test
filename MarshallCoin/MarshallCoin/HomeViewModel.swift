import Foundation
import Combine

@Observable
class HomeViewModel {
    private let maxDaysOld: Int = 7

    @ObservationIgnored
    private var bag: Set<AnyCancellable> = []

    @ObservationIgnored
    private let coinPriceClient: CoinPriceClient

    // Fiat currency properties

    private let currencies: [FiatCurrency]
    private var exchangeRates: FiatExchangeRates = [:]

    // Coin properties

    private var availableCoins: [CoinSymbol] = []
    private var coinPrices: [CoinSymbol: CoinPriceData] = [:]
    private var selectedCoins: [CoinSymbol]

    // Fiat currency interface

    var selectedCurrency: FiatCurrency = .usd

    var currencyViewStates: [CurrencyViewState] {
        currencies.map {
            .init(
                id: $0,
                isSelected: $0 == selectedCurrency,
                name: $0.displayName,
                status: status(for: $0)
            )
        }
    }

    // Coins interface

    func loadAllCoinPrices() async {
        await updateCoinPrices()
    }

    func updateCoinSelection(_ coins: [CoinSymbol]) async {
        selectedCoins = coins
    }

    func updateCoinPrices(symbols: [CoinSymbol]? = nil) async {
        do {
            let newPrices = try await coinPriceClient.coinPrices(symbols)
            // Keep an existing price if the new is missing for some reason
            coinPrices.merge(newPrices) { $1.quoteUSD == nil ? $0 : $1 }
        } catch {
            print("Failed to upload coin list: \(error)")
        }
    }

    var coinPriceViewStates: [CoinPriceViewState] {
        selectedCoins.map { symbol in
            .init(
                symbol: symbol,
                name: coinPrices[symbol]?.name,
                quote: quote(for: symbol, in: selectedCurrency)
            )
        }
    }

    init(
        fiatCurrencyClient: FiatCurrencyClient,
        currencies: [FiatCurrency],
        coinPriceClient: CoinPriceClient,
        coins: [CoinSymbol]
    ) {
        self.currencies = currencies
        self.coinPriceClient = coinPriceClient
        self.selectedCoins = coins

        // The fiat currencies we care about will not change, so we can set this up here
        fiatCurrencyClient
            .exchangeRates(currencies)
            .sink { [weak self] in
                self?.exchangeRates.merge($0) { $1 }
            }
            .store(in: &bag)
    }

    private func status(for currency: FiatCurrency) -> CurrencyViewState.Status {
        if currency.isBaseCurrency { return .isBaseCurrency }
        guard let (rate, date) = exchangeRates[currency] else { return .unavailable }
        let daysOld = -date.timeIntervalSinceNow / (24 * 60 * 60)
        return .available(rate, outdated: daysOld > Double(maxDaysOld))
    }

    private func quote(for symbol: CoinSymbol, in currency: FiatCurrency) -> CoinPriceViewState.DatedQuote? {
        guard let quoteUSD = coinPrices[symbol]?.quoteUSD else { return nil }
        guard let fiatExchangeRate = exchangeRates[currency]?.rate else { return nil }
        let minutesAgo = Int(floor(-quoteUSD.lastUpdated.timeIntervalSinceNow / 60))

        return .init(price: quoteUSD.price * fiatExchangeRate, minAgo: minutesAgo)
    }
}

extension FiatCurrency {
    var displayName: String {
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
