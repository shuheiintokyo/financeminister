import SwiftUI
import Charts

// MARK: - Performance View
struct PerformanceView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @State private var selectedTimeRange: TimeRange = .oneMonth
    
    enum TimeRange: Hashable {
        case oneWeek
        case oneMonth
        case threeMonths
        case oneYear
        case fiveYears
        
        var label: String {
            switch self {
            case .oneWeek: return "1週間"
            case .oneMonth: return "1ヶ月"
            case .threeMonths: return "3ヶ月"
            case .oneYear: return "1年"
            case .fiveYears: return "5年"
            }
        }
        
        var days: Int {
            switch self {
            case .oneWeek: return 7
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .oneYear: return 365
            case .fiveYears: return 1825
            }
        }
    }
    
    // MARK: - Computed Properties
    var filteredHistory: [PortfolioSnapshot] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: now) ?? now
        return viewModel.portfolioHistory.filter { $0.date >= cutoffDate }.sorted { $0.date < $1.date }
    }
    
    var minValue: Double {
        filteredHistory.map { $0.totalValue }.min() ?? 0
    }
    
    var maxValue: Double {
        filteredHistory.map { $0.totalValue }.max() ?? 0
    }
    
    var averageValue: Double {
        guard !filteredHistory.isEmpty else { return 0 }
        let sum = filteredHistory.reduce(0) { $0 + $1.totalValue }
        return sum / Double(filteredHistory.count)
    }
    
    var valueChange: Double {
        guard filteredHistory.count >= 2 else { return 0 }
        return filteredHistory.last!.totalValue - filteredHistory.first!.totalValue
    }
    
    var percentChange: Double {
        guard !filteredHistory.isEmpty, filteredHistory.first!.totalValue != 0 else { return 0 }
        return (valueChange / filteredHistory.first!.totalValue) * 100
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("パフォーマンス")
                            .font(.system(.title2, design: .default))
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Time Range Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach([TimeRange.oneWeek, .oneMonth, .threeMonths, .oneYear, .fiveYears], id: \.self) { range in
                                Button(action: { selectedTimeRange = range }) {
                                    Text(range.label)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTimeRange == range ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedTimeRange == range ? .white : .black)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Portfolio Value Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ポートフォリオ合計評価額")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("¥\(String(format: "%.0f", viewModel.totalPortfolioValue))")
                            .font(.system(.title, design: .default))
                            .fontWeight(.bold)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("変化額")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("¥\(String(format: "%.0f", valueChange))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(valueChange >= 0 ? .green : .red)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("変化率")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(String(format: "%.2f", percentChange))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(percentChange >= 0 ? .green : .red)
                            }
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Line Chart
                    if !filteredHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("推移")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            Chart(filteredHistory) { snapshot in
                                LineMark(
                                    x: .value("Date", snapshot.date),
                                    y: .value("Value", snapshot.totalValue)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                
                                PointMark(
                                    x: .value("Date", snapshot.date),
                                    y: .value("Value", snapshot.totalValue)
                                )
                                .foregroundStyle(.blue)
                                .symbolSize(50)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                    AxisValueLabel()
                                        .font(.caption2)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(position: .bottom) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                    AxisValueLabel(format: .dateTime.month().day())
                                        .font(.caption2)
                                }
                            }
                            .frame(height: 250)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("チャートデータを読み込み中...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    // Chart Statistics
                    VStack(spacing: 12) {
                        StatRow(label: "最高値", value: "¥\(String(format: "%.0f", maxValue))")
                        Divider()
                        StatRow(label: "最安値", value: "¥\(String(format: "%.0f", minValue))")
                        Divider()
                        StatRow(label: "平均値", value: "¥\(String(format: "%.0f", averageValue))")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Holdings Section
                    if !viewModel.holdings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("保有銘柄別構成")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.holdings, id: \.id) { holding in
                                HoldingRowView(holding: holding, exchangeRate: viewModel.exchangeRate)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("パフォーマンス")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Stat Row Component
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Holding Row Component
struct HoldingRowView: View {
    let holding: PortfolioHolding
    let exchangeRate: Double
    
    var holdingValue: Double {
        holding.stock.currentPrice * holding.quantity * exchangeRate
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.stock.name)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(holding.stock.symbol)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(String(format: "%.0f", holdingValue))")
                    .font(.body)
                    .fontWeight(.semibold)
                Text("×\(String(format: "%.2f", holding.quantity))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#if DEBUG
struct PerformanceView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PortfolioViewModel()
        PerformanceView(viewModel: viewModel)
    }
}
#endif
