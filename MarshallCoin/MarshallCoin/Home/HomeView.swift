import SwiftUI

// MARK: Main View

struct HomeView: View {
    @State private var showSelectionSheet: Bool = false
    @State private var detailsVM: CoinDetailsViewModel? = nil

    let vm: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            CurrencySelectionView(viewStates: vm.currencyViewStates) { currency in
                vm.selectedCurrency = currency
            }
            .padding(.bottom, 8)

            ScrollView {
                CoinPricesView(viewStates: vm.coinPriceViewStates) { coinID in
                    detailsVM = vm.makeDetailsVM(coinID)
                } onRemove: { coinID in
                    vm.removeFromSelection(coinID)
                }

                PlusButton {
                    showSelectionSheet.toggle()
                }
                .padding(.top, 10)
            }
        }
        .background(.gray)
        .task {
            await vm.start()
        }
        .sheet(isPresented: $showSelectionSheet) {
            CoinSelectionView(coins: vm.availableCoins, onSelect: vm.addToSelection)
        }
        .sheet(item: $detailsVM) { vm in
            CoinDetailsView(vm: vm)
        }
    }
}

// MARK: Helper Views

struct PlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.4))
                    .frame(width: 50, height: 50)
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
