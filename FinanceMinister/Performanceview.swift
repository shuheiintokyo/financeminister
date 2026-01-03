import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var selectedTimeFrame: TimeFrame = .oneMonth
    @State private var selectedHoldingIndex: Int = 0
    
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
                                if !viewModel.portfolioSummary.holdings.isEmpty {
                                    viewModel.loadHistoricalData(
                                        for: viewModel.portfolioSummary.holdings[selectedHoldingIndex].stock.symbol,
                                        market: viewModel.portfolioSummary.holdings[selectedHoldingIndex].stock.market
                                    )
                                }
                            }
                            
                            // Portfolio Performance Chart
                            portfolioPerformanceCard
                            
                            // Individual Stock Selection
                            if !viewModel.portfolioSummary.holdings.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("個別銘柄")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    Picker("銘柄を選択", selection: $selectedHoldingIndex) {
                                        ForEach(viewModel.portfolioSummary.holdings.indices, id: \.self) { index in
                                            Text(viewModel.portfolioSummary.holdings[index].stock.name)
                                                .tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(.horizontal)
                                    .onChange(of: selectedHoldingIndex) { newIndex in
                                        let holding = viewModel.portfolioSummary.holdings[newIndex]
                                        viewModel.loadHistoricalData(
                                            for: holding.stock.symbol,
                                            market: holding.stock.market
                                        )
                                    }
                                }
                            }
                            
                            // Individual Stock Chart
                            if !viewModel.historicalPrices.isEmpty {
                                individualStockChart
                            }
                            
                            // Statistics
                            statisticsCard
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("パフォーマンス")
            .onAppear {
                viewModel.loadExchangeRateHistory()
                if !viewModel.portfolioSummary.holdings.isEmpty {
                    viewModel.loadHistoricalData(
                        for: viewModel.portfolioSummary.holdings[0].stock.symbol,
                        market: viewModel.portfolioSummary.holdings[0].stock.market
                    )
                }
            }
        }
    }
    
    // MARK: - Portfolio Performance Card
    private var portfolioPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ポートフォリオパフォーマンス")
                .font(.headline)
            
            if !viewModel.historicalExchangeRates.isEmpty {
                // Simple line chart representation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("為替レート (USD/JPY)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        let minRate = viewModel.historicalExchangeRates.map { $0.rate }.min() ?? 0
                        let maxRate = viewModel.historicalExchangeRates.map { $0.rate }.max() ?? 0
                        
                        Text("¥\(formatCurrency(minRate)) - ¥\(formatCurrency(maxRate))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Chart placeholder
                    ZStack {
                        Color(.systemGray6)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 2) {
                                ForEach(viewModel.historicalExchangeRates.prefix(30), id: \.id) { history in
                                    let minRate = viewModel.historicalExchangeRates.map { $0.rate }.min() ?? 0
                                    let maxRate = viewModel.historicalExchangeRates.map { $0.rate }.max() ?? 0
                                    let range = maxRate - minRate
                                    
                                    let height = range > 0 ? CGFloat((history.rate - minRate) / range) * 100 : 50
                                    
                                    VStack {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.blue.opacity(0.6))
                                            .frame(height: height)
                                    }
                                }
                            }
                            .frame(height: 120)
                            
                            Text(selectedTimeFrame.displayName)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .cornerRadius(8)
                    .frame(height: 160)
                }
            } else {
                Text("データ読み込み中...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: 160)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Individual Stock Chart
    private var individualStockChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            if selectedHoldingIndex < viewModel.portfolioSummary.holdings.count {
                let holding = viewModel.portfolioSummary.holdings[selectedHoldingIndex]
                
                Text("\(holding.stock.name)の価格推移")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("価格")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        let minPrice = viewModel.historicalPrices.map { $0.price }.min() ?? 0
                        let maxPrice = viewModel.historicalPrices.map { $0.price }.max() ?? 0
                        
                        Text("\(formatCurrency(minPrice)) - \(formatCurrency(maxPrice))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    ZStack {
                        Color(.systemGray6)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 2) {
                                ForEach(viewModel.historicalPrices.prefix(30), id: \.id) { history in
                                    let minPrice = viewModel.historicalPrices.map { $0.price }.min() ?? 0
                                    let maxPrice = viewModel.historicalPrices.map { $0.price }.max() ?? 0
                                    let range = maxPrice - minPrice
                                    
                                    let height = range > 0 ? CGFloat((history.price - minPrice) / range) * 100 : 50
                                    
                                    VStack {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.green.opacity(0.6))
                                            .frame(height: height)
                                    }
                                }
                            }
                            .frame(height: 120)
                            
                            Text(selectedTimeFrame.displayName)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .cornerRadius(8)
                    .frame(height: 160)
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
            
            if selectedHoldingIndex < viewModel.portfolioSummary.holdings.count {
                let holding = viewModel.portfolioSummary.holdings[selectedHoldingIndex]
                
                VStack(spacing: 8) {
                    StatisticRow(label: "現在価格", value: "\(formatCurrency(holding.stock.currentPrice)) \(holding.stock.currency)")
                    StatisticRow(label: "数量", value: "\(holding.quantity, specifier: "%.4g")")
                    StatisticRow(label: "評価額", value: "¥\(formatCurrency(holding.stock.market == .american ? holding.currentValue * viewModel.currentExchangeRate : holding.currentValue))")
                    StatisticRow(label: "評価損益", value: "¥\(formatCurrency(holding.stock.market == .american ? holding.gainLoss * viewModel.currentExchangeRate : holding.gainLoss))", valueColor: holding.gainLoss >= 0 ? .green : .red)
                    StatisticRow(label: "騰落率", value: "\(holding.gainLossPercentage, specifier: "%.2f")%", valueColor: holding.gainLossPercentage >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

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

#Preview {
    PerformanceView()
        .environmentObject(PortfolioViewModel())
}
