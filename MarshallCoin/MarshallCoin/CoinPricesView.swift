import SwiftUI

struct CoinPricesView: View {
    let viewStates: [CoinPriceViewState]
    let onSelect: (CoinID) -> Void
    let onRemove: ((CoinID) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewStates) { viewState in
                    Button {
                        onSelect(viewState.id)
                    } label: {
                        CoinPriceView(viewState: viewState)
                    }
                    .contextMenu {
                        if let onRemove {
                            Button("Details", systemImage: "chart.line.uptrend.xyaxis") {
                                onSelect(viewState.id)
                            }
                            Button("Remove coin", systemImage: "minus") {
                                onRemove(viewState.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .animation(.default, value: viewStates)
        .frame(maxWidth: .infinity)
    }
}

struct CoinPriceViewState: Equatable, Identifiable {
    let id: Int
    let symbol: String
    let name: String
    let decimals: Int
    var quote: DatedQuote?

    struct DatedQuote: Equatable {
        let price: Double
        let minAgo: Int

        var label: String {
            minAgo == 0 ? "Just now" : "\(minAgo) min ago"
        }
    }
}

struct CoinPriceView: View {
    let viewState: CoinPriceViewState

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewState.symbol)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))

                Text(viewState.name)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if let quote = viewState.quote {
                VStack(alignment: .trailing) {
                    Text("\(quote.price, format: .number.precision(.fractionLength(viewState.decimals)))")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(quote.label)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.1))
        }
    }
}
