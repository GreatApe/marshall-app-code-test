import SwiftUI

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
            .refreshable {
                await vm.updateCoinPrices()
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

struct CoinSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let coins: [CoinPriceViewState]
    let onSelect: (CoinID) -> Void

    var body: some View {
        NavigationStack {
            CoinPricesView(viewStates: coins, onSelect: onSelect, onRemove: nil)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Select more coins")
                            .foregroundStyle(.white)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
    }
}

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
