import SwiftUI

struct CurrencyViewState: Equatable, Identifiable {
    let id: FiatCurrency
    let isSelected: Bool
    let name: String
    let status: Status

    enum Status: Equatable {
        case unavailable
        case isBaseCurrency
        case available(Double, outdated: Bool)
    }
}

struct CurrencyView: View {
    @ScaledMetric
    private var width: CGFloat = 80

    let viewState: CurrencyViewState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack {
                Text(viewState.name)
                    .bold()
                    .foregroundStyle(.white.opacity(0.8))

                switch viewState.status {
                case .isBaseCurrency:
                    Text("123") // Invisible dummy to ensure layout
                        .opacity(0)
                case .unavailable:
                    Text("N/A")
                        .foregroundStyle(.red)
                case .available(let rate, let outdated):
                    Text("\(rate, format: .number.precision(.fractionLength(2)))")
                        .foregroundStyle(outdated ? .red : .white.opacity(0.7))
                }
            }
            .frame(minWidth: width)
            .padding(7)
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.blue.opacity(viewState.isSelected ? 0.3 : 0.1))
        }
    }
}
