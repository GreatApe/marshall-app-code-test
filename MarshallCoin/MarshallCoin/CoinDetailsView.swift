import SwiftUI

@Observable
class CoinDetailsViewModel {
    private let coinPriceClient: CoinPriceClient
    private let fiatCurrency: FiatCurrency
    private let fiatExchangeRate: Double

    let priceVM: CoinPriceViewState

    init(priceVM: CoinPriceViewState, fiatCurrency: FiatCurrency, fiatExchangeRate: Double, coinPriceClient: CoinPriceClient) {
        self.coinPriceClient = coinPriceClient
        self.fiatCurrency = fiatCurrency
        self.fiatExchangeRate = fiatExchangeRate
        self.priceVM = priceVM
    }

    var priceHistory: [Double]? = nil
}

extension CoinDetailsViewModel: Identifiable {
    var id: CoinID { priceVM.id }
}

struct CoinDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let vm: CoinDetailsViewModel

    var body: some View {
        NavigationStack {
            CoinPriceView(viewState: vm.priceVM)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(vm.priceVM.name)
                            .foregroundStyle(.white)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .border(.red)
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium])
    }
}
