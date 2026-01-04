import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var selectedTimeFrame: TimeFrame = .oneMonth
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.portfolioSummary.holdings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("データがありません")
                            .font(.headline)
                        
                        Text("ポートフォリオタブから株を追加してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Time Frame Picker
                            Picker("期間", selection: $selectedTimeFrame) {
                                ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                                    Text(timeFrame.displayName).tag(timeFrame)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            .onChange(of: selectedTimeFrame) { newValue in
                                viewModel.selectedTimeFrame = newValue
                                viewModel.loadExchangeRateHistory()
                                // Reload all historical data for all holdings
                                for holding in viewModel.portfolioSummary.holdings {
                                    viewModel.loadHistoricalData(
                                        for: holding.stock.symbol,
                                        market: holding.stock.market
                                    )
                                }
                            }
                            
                            // Show Error Message if Connection Failed
                            if let errorMessage = viewModel.errorMessage {
                                VStack(spacing: 16) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 48))
                                        .foregroundColor(.red)
                                    
                                    Text(errorMessage)
                                        .font(.headline)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("インターネット接続を確認して、もう一度試してください。")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: {
                                        viewModel.loadExchangeRateHistory()
                                        for holding in viewModel.portfolioSummary.holdings {
                                            viewModel.loadHistoricalData(
                                                for: holding.stock.symbol,
                                                market: holding.stock.market
                                            )
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("再試行")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            } else {
                                // Portfolio Total Value Chart (Stacked Area)
                                portfolioStackedAreaChart
                                
                                // Holdings Legend
                                holdingsLegend
                                
                                // Statistics
                                statisticsCard
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("パフォーマンス")
            .onAppear {
                viewModel.loadExchangeRateHistory()
                // Load historical data for all holdings
                for holding in viewModel.portfolioSummary.holdings {
                    viewModel.loadHistoricalData(
                        for: holding.stock.symbol,
                        market: holding.stock.market
                    )
                }
            }
        }
    }
    
    // MARK: - Portfolio Stacked Area Chart
    private var portfolioStackedAreaChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ポートフォリオ合計評価額")
                .font(.headline)
            
            // Calculate max value for Y-axis
            let maxPortfolioValue = calculateMaxPortfolioValue()
            
            // Stacked Area Chart with Y-axis labels
            HStack(spacing: 8) {
                // Y-axis labels
                VStack(spacing: 0) {
                    Text("¥\(formatCurrency(maxPortfolioValue))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(height: 40)
                    
                    Spacer()
                    
                    Text("¥0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(height: 40)
                }
                .frame(width: 60)
                
                // Chart
                ZStack {
                    Color(.systemGray6)
                    
                    if !viewModel.historicalExchangeRates.isEmpty {
                        Canvas { context, size in
                            let holdings = viewModel.portfolioSummary.holdings
                            let exchangeRates = viewModel.historicalExchangeRates
                            
                            guard !holdings.isEmpty, !exchangeRates.isEmpty else { return }
                            
                            let width = 280.0
                            let height = 150.0
                            
                            // Define colors for each holding
                            let colors: [Color] = [
                                Color.blue,
                                Color.green,
                                Color.orange,
                                Color.red,
                                Color.purple,
                                Color.pink
                            ]
                            
                            // Calculate portfolio value at each historical point
                            var portfolioValues: [[Double]] = Array(repeating: [], count: holdings.count)
                            var maxTotalValue: Double = 0
                            
                            for (dateIndex, rate) in exchangeRates.enumerated() {
                                var dayTotal = 0.0
                                
                                for (holdingIndex, holding) in holdings.enumerated() {
                                    // Find price at this date
                                    let holdingPrices = viewModel.historicalPrices.filter {
                                        $0.symbol == holding.stock.symbol
                                    }
                                    
                                    let price = holdingPrices.isEmpty ? holding.stock.currentPrice :
                                               (holdingPrices.first?.price ?? holding.stock.currentPrice)
                                    
                                    let value = price * holding.quantity
                                    let valueInJpy = holding.stock.market == .american ?
                                                    (value * rate.rate) : value
                                    
                                    portfolioValues[holdingIndex].append(valueInJpy)
                                    dayTotal += valueInJpy
                                }
                                
                                maxTotalValue = max(maxTotalValue, dayTotal)
                            }
                            
                            // Draw stacked areas from bottom to top
                            var cumulativeValues: [Double] = Array(repeating: 0, count: exchangeRates.count)
                            
                            for (holdingIndex, holding) in holdings.enumerated() {
                                let color = colors[holdingIndex % colors.count]
                                var path = Path()
                                
                                // Bottom line (cumulative from previous holdings)
                                let firstBottomY = height - (cumulativeValues[0] / max(maxTotalValue, 1)) * height
                                path.move(to: CGPoint(x: 8, y: firstBottomY))
                                
                                // Top line (cumulative including this holding)
                                for (dateIndex, rate) in exchangeRates.enumerated() {
                                    let stepX = (width / CGFloat(max(exchangeRates.count - 1, 1)))
                                    let x = CGFloat(dateIndex) * stepX + 8
                                    
                                    cumulativeValues[dateIndex] += portfolioValues[holdingIndex][dateIndex]
                                    let y = height - (cumulativeValues[dateIndex] / max(maxTotalValue, 1)) * height
                                    
                                    path.addLine(to: CGPoint(x: x, y: y + 8))
                                }
                                
                                // Back down along the bottom
                                for dateIndex in stride(from: exchangeRates.count - 1, through: 0, by: -1) {
                                    let stepX = (width / CGFloat(max(exchangeRates.count - 1, 1)))
                                    let x = CGFloat(dateIndex) * stepX + 8
                                    
                                    let previousCumulative = cumulativeValues[dateIndex] - portfolioValues[holdingIndex][dateIndex]
                                    let y = height - (previousCumulative / max(maxTotalValue, 1)) * height
                                    
                                    path.addLine(to: CGPoint(x: x, y: y + 8))
                                }
                                
                                path.closeSubpath()
                                
                                // Fill with color
                                context.fill(
                                    path,
                                    with: .color(color.opacity(0.7))
                                )
                                
                                // Draw border
                                context.stroke(
                                    path,
                                    with: .color(color),
                                    lineWidth: 1.5
                                )
                            }
                        }
                        .frame(height: 200)
                    } else {
                        VStack {
                            ProgressView()
                            Text("チャートデータを読み込み中...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Text(selectedTimeFrame.displayName)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // Calculate max portfolio value for Y-axis
    private func calculateMaxPortfolioValue() -> Double {
        var maxValue = 0.0
        
        for rate in viewModel.historicalExchangeRates {
            var dayTotal = 0.0
            
            for holding in viewModel.portfolioSummary.holdings {
                let price = holding.stock.currentPrice
                let value = price * holding.quantity
                let valueInJpy = holding.stock.market == .american ? (value * rate.rate) : value
                dayTotal += valueInJpy
            }
            
            maxValue = max(maxValue, dayTotal)
        }
        
        return maxValue
    }
    
    // MARK: - Holdings Legend
    private var holdingsLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("保有銘柄別構成")
                .font(.headline)
            
            let colors: [Color] = [
                Color.blue,
                Color.green,
                Color.orange,
                Color.red,
                Color.purple,
                Color.pink
            ]
            
            VStack(spacing: 8) {
                ForEach(viewModel.portfolioSummary.holdings.indices, id: \.self) { index in
                    let holding = viewModel.portfolioSummary.holdings[index]
                    let color = colors[index % colors.count]
                    
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.7))
                            .frame(width: 16, height: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holding.stock.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(holding.stock.symbol)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("¥\(formatCurrency(holding.stock.market == .american ? holding.currentValue * viewModel.currentExchangeRate : holding.currentValue))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Statistics Card
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計")
                .font(.headline)
            
            VStack(spacing: 8) {
                StatisticRow(
                    label: "現在のポートフォリオ評価額",
                    value: "¥\(formatCurrency(viewModel.portfolioSummary.totalValueInJpy))"
                )
                
                StatisticRow(
                    label: "現在の為替レート",
                    value: "¥\(String(format: "%.2f", viewModel.currentExchangeRate)) / USD"
                )
                
                StatisticRow(
                    label: "保有銘柄数",
                    value: "\(viewModel.portfolioSummary.holdings.count)"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views
struct StatisticRow: View {
    let label: String
    let value: String
    var valueColor: Color = .black
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Function
func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

#Preview {
    PerformanceView()
        .environmentObject(PortfolioViewModel())
}
