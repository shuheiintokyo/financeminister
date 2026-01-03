import Foundation
import Combine
import CoreData

class PortfolioViewModel: ObservableObject {
    @Published var holdings: [PortfolioHolding] = []
    @Published var currentExchangeRate: Double = 149.50
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTimeFrame: TimeFrame = .oneMonth
    @Published var historicalPrices: [PriceHistory] = []
    @Published var historicalExchangeRates: [ExchangeRateHistory] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let persistenceController = PersistenceController.shared
    
    init() {
        loadHoldings()
        refreshExchangeRate()
    }
    
    // MARK: - Portfolio Management
    
    func addHolding(_ holding: PortfolioHolding) {
        holdings.append(holding)
        persistenceController.saveHolding(holding)
    }
    
    func removeHolding(_ holding: PortfolioHolding) {
        holdings.removeAll { $0.id == holding.id }
        persistenceController.deleteHolding(holding)
    }
    
    func updateHolding(_ holding: PortfolioHolding) {
        if let index = holdings.firstIndex(where: { $0.id == holding.id }) {
            holdings[index] = holding
            persistenceController.saveHolding(holding)
        }
    }
    
    // MARK: - Portfolio Summary Calculation
    
    var portfolioSummary: PortfolioSummary {
        var totalInJapanese: Double = 0
        var totalInAmerican: Double = 0
        var totalGainLoss: Double = 0
        
        for holding in holdings {
            let valueInJpy: Double
            
            switch holding.stock.market {
            case .japanese:
                valueInJpy = holding.currentValue
                totalInJapanese += valueInJpy
            case .american:
                valueInJpy = holding.currentValue * currentExchangeRate
                totalInAmerican += valueInJpy
            }
            
            totalGainLoss += holding.gainLoss * (holding.stock.market == .american ? currentExchangeRate : 1.0)
        }
        
        let totalValue = totalInJapanese + totalInAmerican
        let totalCost = holdings.reduce(0) { acc, holding in
            let cost = (holding.purchasePrice * holding.quantity)
            if holding.stock.market == .american {
                return acc + (cost * currentExchangeRate)
            } else {
                return acc + cost
            }
        }
        
        let gainLossPercentage = totalCost > 0 ? (totalGainLoss / totalCost) * 100 : 0
        
        return PortfolioSummary(
            totalValueInJpy: totalValue,
            totalInJapaneseStocks: totalInJapanese,
            totalInAmericanStocks: totalInAmerican,
            currentExchangeRate: currentExchangeRate,
            totalGainLoss: totalGainLoss,
            totalGainLossPercentage: gainLossPercentage,
            holdings: holdings
        )
    }
    
    // MARK: - Data Refreshing
    
    func refreshPortfolio() {
        isLoading = true
        refreshExchangeRate()
        isLoading = false
    }
    
    func refreshExchangeRate() {
        // モック実装
        currentExchangeRate = 149.50
    }
    
    func loadHistoricalData(for symbol: String, market: MarketType) {
        // モック実装：過去30日分の価格データを生成
        var mockPrices: [PriceHistory] = []
        for i in 0..<30 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let volatility = Double.random(in: -0.05...0.05)
            let basePrice = market == .american ? 150.0 : 5000.0
            let price = basePrice * (1 + volatility)
            mockPrices.append(PriceHistory(date: date, price: price, symbol: symbol, market: market))
        }
        historicalPrices = mockPrices.sorted { $0.date < $1.date }
    }
    
    func loadExchangeRateHistory() {
        // モック実装：過去30日分の為替レートを生成
        var mockRates: [ExchangeRateHistory] = []
        for i in 0..<30 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let volatility = Double.random(in: -0.02...0.02)
            let baseRate = 149.50
            let rate = baseRate * (1 + volatility)
            mockRates.append(ExchangeRateHistory(date: date, rate: rate))
        }
        historicalExchangeRates = mockRates.sorted { $0.date < $1.date }
    }
    
    // MARK: - Data Persistence with Core Data
    
    func loadHoldings() {
        holdings = persistenceController.loadHoldings()
    }
    
    func clearAllHoldings() {
        holdings.removeAll()
        persistenceController.clearAllHoldings()
    }
}

// MARK: - Stock Search ViewModel
class StockSearchViewModel: ObservableObject {
    @Published var searchResults: [Stock] = []
    @Published var isSearching = false
    
    func searchStocks(query: String, market: MarketType) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // モック実装：サンプルデータを返す
        let mockJapaneseStocks = [
            Stock(id: "9984", symbol: "9984.T", name: "ソフトバンクグループ", market: .japanese, currentPrice: 6850.0, currency: "JPY"),
            Stock(id: "8306", symbol: "8306.T", name: "三菱UFJフィナンシャル", market: .japanese, currentPrice: 2800.0, currency: "JPY"),
            Stock(id: "6758", symbol: "6758.T", name: "ソニーグループ", market: .japanese, currentPrice: 7450.0, currency: "JPY"),
        ]
        
        let mockAmericanStocks = [
            Stock(id: "AAPL", symbol: "AAPL", name: "Apple Inc.", market: .american, currentPrice: 185.50, currency: "USD"),
            Stock(id: "MSFT", symbol: "MSFT", name: "Microsoft Corp.", market: .american, currentPrice: 430.75, currency: "USD"),
            Stock(id: "GOOGL", symbol: "GOOGL", name: "Alphabet Inc.", market: .american, currentPrice: 140.20, currency: "USD"),
        ]
        
        let allStocks = mockJapaneseStocks + mockAmericanStocks
        let filtered = allStocks.filter {
            $0.symbol.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query)
        }
        
        searchResults = filtered
        isSearching = false
    }
}
