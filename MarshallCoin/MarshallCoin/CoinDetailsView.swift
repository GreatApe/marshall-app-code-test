import SwiftUI
import Charts

struct CoinDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let vm: CoinDetailsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 15) {
                    CoinDetailView(label: "Name", value: vm.priceVM.name)

                    if let quote = vm.priceVM.quote {
                        CoinDetailView(label: "Latest price", value: quote.price, decimals: vm.priceVM.decimals)
                    }

                    CoinDetailView(label: "Market cap", value: vm.details.marketCap)

                    CoinDetailView(label: "Volume 24h", value: vm.details.volume24g)
                }
                .inCard

                if let history = vm.priceHistory {
                    Chart(history, id: \.timestamp) { quote in
                        LineMark(
                            x: .value("Day", quote.timestamp, unit: .day),
                            y: .value("Price", quote.price)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.yellow.opacity(0.5))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisValueLabel(format: .dateTime.day(), centered: true)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            let format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(vm.priceVM.decimals))
                            AxisValueLabel(format: format, centered: true)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(10)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 15)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(vm.priceVM.symbol) in \(vm.currencyLabel)")
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
        .presentationDetents([.medium])
        .task {
            await vm.loadHistory()
        }
    }
}

struct CoinDetailView: View {
    let label: String
    let text: Text

    init(label: String, value: Double, decimals: Int = 0) {
        self.label = label
        self.text = Text("\(value, format: .number.precision(.fractionLength(decimals)))")
    }

    init(label: String, value: String) {
        self.label = label
        self.text = Text(value)
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            text
                .foregroundStyle(.white.opacity(0.9))
                .bold()
        }
    }
}
