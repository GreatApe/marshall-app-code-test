import SwiftUI

struct HomeView: View {
    @State 
    private var vm = HomeViewModel(
        fiatCurrencyClient: .mock,
        currencies: [.usd, .sek, .dkk],
        coinPriceClient: .live,
        coins: ["BTC", "ETH", "SOL"]
    )

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(vm.currencyViewStates) { viewState in
                        CurrencyView(viewState: viewState) {
                            vm.selectedCurrency = viewState.id
                        }
                    }

                    Button("+") {

                    }
                    .background {
                        Circle()
                            .fill(.blue.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.never)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 15) {
                    ForEach(vm.coinPriceViewStates) { viewState in
                        CoinPriceView(viewState: viewState)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(.gray)
        .task {
            await vm.loadAllCoinPrices()
        }
    }
}

struct CoinPriceViewState: Equatable {
    let symbol: CoinSymbol
    let name: String?
    var quote: DatedQuote?

    struct DatedQuote: Equatable {
        let price: Double
        let minAgo: Int

        var label: String {
            minAgo == 0 ? "Just now" : "\(minAgo) min ago"
        }
    }
}

extension CoinPriceViewState: Identifiable {
    var id: CoinSymbol { symbol }
}

struct CoinPriceView: View {
    let viewState: CoinPriceViewState

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewState.symbol)
                    .bold()

                if let name = viewState.name {
                    Text(name)
                        .font(.footnote)
                }
            }

            Spacer()

            if let quote = viewState.quote {
                VStack(alignment: .trailing) {
                    Text("\(quote.price, format: .number.precision(.fractionLength(2)))")

                    Text(quote.label)
                        .font(.footnote)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
