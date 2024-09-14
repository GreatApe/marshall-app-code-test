import SwiftUI

@Observable
class CoinDetailsViewModel {
    let coinPriceClient: CoinPriceClient
    private let fiatCurrency: FiatCurrency
    private let fiatExchangeRate: Double

    // Interface

    let priceVM: CoinPriceViewState

    var priceHistory: [DatedQuote]? = nil

    var currencyLabel: String {
        fiatCurrency.displayName
    }

    let details: CoinDetails

    func loadHistory() async {
        guard let priceHistoryUSD = try? await coinPriceClient.priceHistory(id) else { return }
        priceHistory = priceHistoryUSD.map {
            .init(timestamp: $0.timestamp, price: $0.price * fiatExchangeRate)
        }
    }

    init(
        priceVM: CoinPriceViewState,
        details: CoinDetails,
        fiatCurrency: FiatCurrency,
        fiatExchangeRate: Double,
        coinPriceClient: CoinPriceClient
    ) {
        self.coinPriceClient = coinPriceClient
        self.fiatCurrency = fiatCurrency
        self.fiatExchangeRate = fiatExchangeRate
        self.priceVM = priceVM
        self.details = details
    }

    struct CoinDetails: Equatable {
        let marketCap: Double
        let volume24g: Double
    }
}

extension CoinDetailsViewModel: Identifiable {
    var id: CoinID { priceVM.id }
}

