import SwiftUI

@main
struct MarshallCoinApp: App {
    @State private var vm = HomeViewModel(
        fiatCurrencyClient: .mock,
        currencies: [.usd, .eur, .sek, .dkk],
        coinPriceClient: .live,
        coins: [1, 1027]
    )

    var body: some Scene {
        WindowGroup {
            HomeView(vm: vm)
        }
    }
}
