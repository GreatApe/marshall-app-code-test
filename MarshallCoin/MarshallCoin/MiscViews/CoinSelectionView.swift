import SwiftUI

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
