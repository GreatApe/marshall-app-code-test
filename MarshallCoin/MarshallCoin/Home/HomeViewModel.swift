import Foundation
import Combine

@Observable
class HomeViewModel {

    // Constants

    private let maxDaysOld: Int = 7
    private let decimals: [CoinID: Int] = [1: 0, 2: 2, 52: 3, 24478: 8, 1027: 0, 5426: 2]
    private let defaultDecimals: Int = 2

    @ObservationIgnored
    private var bag: Set<AnyCancellable> = []

    @ObservationIgnored
    private let coinPriceClient: CoinPriceClient

    // Fiat currency properties

    private let currencies: [FiatCurrency]
    private var exchangeRates: FiatExchangeRates = [:]

    // Coin properties

    private var selectedCoins: CurrentValueSubject<[CoinID], Never> = .init([])

    private var coinPrices: [CoinID: CoinPriceData] = [:]

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

    func start() async {
        do {
            let prices = try await coinPriceClient.listedCoins()
            coinPrices = Dictionary(prices.map { ($0.id, $0) }) { $1 }
        } catch {
            print("Failed to load coin list: \(error)")
        }
    }

    func removeFromSelection(_ coin: CoinID) {
        selectedCoins.value.removeAll { $0 == coin }
    }

    func addToSelection(_ coin: CoinID) {
        assert(!selectedCoins.value.contains(coin), "Should not be possible to add already selected coin")
        selectedCoins.value.append(coin)
    }

    var coinPriceViewStates: [CoinPriceViewState] {
        selectedCoins.value.compactMap { id in
            guard let coinData = coinPrices[id] else { return nil }
            return .init(
                id: id,
                symbol: coinData.symbol,
                name: coinData.name,
                decimals: decimalCount(for: id, in: selectedCurrency),
                quote: quote(for: id, in: selectedCurrency)
            )
        }
    }

    var availableCoins: [CoinPriceViewState] {
        coinPrices.values
            .filter { !selectedCoins.value.contains($0.id) }
            .sorted { $0.symbol < $1.symbol }
            .map { coin in
                .init(
                    id: coin.id,
                    symbol: coin.symbol,
                    name: coin.name,
                    decimals: decimalCount(for: coin.id, in: selectedCurrency),
                    quote: coin.quoteUSD.flatMap { convertQuote($0, to: selectedCurrency) }
                )
            }
    }

    // Details View Model

    func makeDetailsVM(_ coin: CoinID) -> CoinDetailsViewModel? {
        guard let priceVM = coinPriceViewStates.first(where: { $0.id == coin }) else {
            assertionFailure("Should only be possible to select a coin that is in `coinPriceViewStates`")
            return nil
        }
        guard let fiatExchangeRate = exchangeRates[selectedCurrency]?.rate else {
            assertionFailure("We should always have the rate for `selectedCurrency`")
            return nil
        }

        guard let quoteUSD = coinPrices[coin]?.quoteUSD else {
            assertionFailure("We should always have the `quoteUSD` in `coinPrices` for the selected coin")
            return nil
        }

        return .init(
            priceVM: priceVM, 
            details: .init(marketCap: quoteUSD.marketCap * fiatExchangeRate, volume24g: quoteUSD.volume24h * fiatExchangeRate),
            fiatCurrency: selectedCurrency,
            fiatExchangeRate: fiatExchangeRate, 
            coinPriceClient: coinPriceClient
        )
    }

    init(
        fiatCurrencyClient: FiatCurrencyClient,
        currencies: [FiatCurrency],
        coinPriceClient: CoinPriceClient,
        coins: [CoinID]
    ) {
        self.currencies = currencies
        self.coinPriceClient = coinPriceClient

        // The fiat currencies we care about will not change, so we can set this up here
        fiatCurrencyClient
            .exchangeRates(currencies)
            .sink { [weak self] in
                self?.exchangeRates.merge($0) { $1 }
            }
            .store(in: &bag)

        coinPriceClient
            .prices(selectedCoins.eraseToAnyPublisher())
            .sink { [weak self] newPrices in
                // Ignore new values that lack quoteUSD
                self?.coinPrices.merge(newPrices) { $1.quoteUSD == nil ? $0 : $1 }
            }
            .store(in: &bag)

        selectedCoins.value = coins
    }

    private func decimalCount(for coin: CoinID, in currency: FiatCurrency) -> Int {
        let decimalsInUSD = decimals[coin] ?? defaultDecimals
        let decimalsInCurrency = decimalsInUSD + currency.extraDecimals
        if decimalsInCurrency < 0 {
            return 0
        } else if decimalsInCurrency == 1 {
            // Might as well add a decimal here, looks better
            return 2
        }
        return decimalsInCurrency
    }
    
    private func status(for currency: FiatCurrency) -> CurrencyViewState.Status {
        if currency.isBase { return .isBaseCurrency }
        guard let (rate, date) = exchangeRates[currency] else { return .unavailable }
        let daysOld = -date.timeIntervalSinceNow / (24 * 60 * 60)
        return .available(rate, outdated: daysOld > Double(maxDaysOld))
    }

    private func quote(for id: CoinID, in currency: FiatCurrency) -> CoinPriceViewState.DatedQuote? {
        guard let quoteUSD = coinPrices[id]?.quoteUSD else { return nil }
        return convertQuote(quoteUSD, to: currency)
    }

    private func convertQuote(_ quoteUSD: CoinPriceQuote, to currency: FiatCurrency) -> CoinPriceViewState.DatedQuote? {
        guard let fiatExchangeRate = exchangeRates[currency]?.rate else { return nil }
        let minutesAgo = Int(floor(-quoteUSD.lastUpdated.timeIntervalSinceNow / 60))

        // Let's pretend that the API can give us fresh data, just for demo purposes
        let fakeMinutesAgo = max(minutesAgo - 1, 0)

        return .init(price: quoteUSD.price * fiatExchangeRate, minAgo: fakeMinutesAgo)
    }
}

extension FiatCurrency {
    var displayName: String {
        rawValue
    }

    // Extra decimals compared to USD
    var extraDecimals: Int {
        switch self {
        case .usd, .eur:
            0
        case .sek, .dkk, .nok:
            -1
        case .yen:
            -2
        }
    }
}
