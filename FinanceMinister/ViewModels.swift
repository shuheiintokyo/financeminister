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
        print("DEBUG: Adding holding - \(holding.stock.symbol), qty: \(holding.quantity)")
        holdings.append(holding)
        persistenceController.saveHolding(holding)
    }
    
    func removeHolding(_ holding: PortfolioHolding) {
        print("DEBUG: Removing holding - \(holding.stock.symbol)")
        holdings.removeAll { $0.id == holding.id }
        persistenceController.deleteHolding(holding)
    }
    
    func updateHolding(_ holding: PortfolioHolding) {
        if let index = holdings.firstIndex(where: { $0.id == holding.id }) {
            holdings[index] = holding
            persistenceController.saveHolding(holding)
        }
    }
    
    // MARK: - Portfolio Summary Calculation (SIMPLIFIED - Only Values, No Gain/Loss)
    
    var portfolioSummary: PortfolioSummary {
        var totalValueInJpy: Double = 0
        var totalCostBasis: Double = 0
        
        // Calculate total current value and cost basis
        for holding in holdings {
            let valueInJpy: Double
            let costInJpy: Double
            
            if holding.stock.market == .american {
                // Convert USD to JPY
                valueInJpy = holding.currentValue * currentExchangeRate
                costInJpy = (holding.purchasePrice * holding.quantity) * currentExchangeRate
            } else {
                // Already in JPY
                valueInJpy = holding.currentValue
                costInJpy = holding.purchasePrice * holding.quantity
            }
            
            totalValueInJpy += valueInJpy
            totalCostBasis += costInJpy
        }
        
        print("DEBUG: Portfolio Summary")
        print("  - Total Value in JPY: ¥\(totalValueInJpy)")
        print("  - Total Cost Basis: ¥\(totalCostBasis)")
        print("  - Holdings Count: \(holdings.count)")
        
        return PortfolioSummary(
            totalValueInJpy: totalValueInJpy,
            totalCostBasis: totalCostBasis,
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
        print("DEBUG: Refreshing current exchange rate (USD/JPY)")
        
        // Fetch real current exchange rate
        StockAPIService.shared.fetchStockPrice(symbol: "JPY=X", market: .american)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("DEBUG: Exchange rate fetch failed: \(error)")
                    // Fallback to last known rate
                    print("DEBUG: Using last known rate: ¥\(self?.currentExchangeRate ?? 149.50)")
                case .finished:
                    print("DEBUG: Current exchange rate updated successfully")
                }
            } receiveValue: { [weak self] rate in
                self?.currentExchangeRate = rate
                print("DEBUG: Current exchange rate: ¥\(rate) per USD")
            }
            .store(in: &cancellables)
    }
    
    func loadHistoricalData(for symbol: String, market: MarketType) {
        print("DEBUG: Loading historical data for \(symbol)")
        
        // Format symbol for Yahoo Finance
        let yahooSymbol = market == .american ? symbol : symbol
        
        // Fetch real data from Yahoo Finance
        StockAPIService.shared.fetchHistoricalData(symbol: yahooSymbol, market: market)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("DEBUG: Historical data API error: \(error.localizedDescription)")
                    self?.errorMessage = "接続に失敗しました。データを取得できません。"
                    self?.historicalPrices = []  // Clear all data on error
                case .finished:
                    print("DEBUG: Historical data loaded successfully")
                    self?.errorMessage = nil  // Clear error message on success
                }
            } receiveValue: { [weak self] prices in
                self?.historicalPrices = prices
                self?.errorMessage = nil  // Clear error on success
                print("DEBUG: Loaded \(prices.count) price history points")
                if let firstPrice = prices.first, let lastPrice = prices.last {
                    print("  - Date range: \(firstPrice.date) to \(lastPrice.date)")
                    print("  - Price range: \(firstPrice.price) to \(lastPrice.price)")
                }
            }
            .store(in: &cancellables)
    }
    
    func loadExchangeRateHistory() {
        print("DEBUG: Loading exchange rate history")
        
        // Fetch real exchange rates
        StockAPIService.shared.fetchExchangeRateHistory()
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("DEBUG: Exchange rate history API error: \(error.localizedDescription)")
                    self?.errorMessage = "接続に失敗しました。為替レート履歴を取得できません。"
                    self?.historicalExchangeRates = []  // Clear all data on error
                case .finished:
                    print("DEBUG: Exchange rate history loaded successfully")
                    self?.errorMessage = nil  // Clear error message on success
                }
            } receiveValue: { [weak self] rates in
                self?.historicalExchangeRates = rates
                self?.errorMessage = nil  // Clear error on success
                print("DEBUG: Loaded \(rates.count) exchange rate history points")
                if let firstRate = rates.first, let lastRate = rates.last {
                    print("  - Date range: \(firstRate.date) to \(lastRate.date)")
                    print("  - Rate range: \(firstRate.rate) to \(lastRate.rate)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Persistence with Core Data
    
    func loadHoldings() {
        let loaded = persistenceController.loadHoldings()
        print("DEBUG: Loaded \(loaded.count) holdings from Core Data")
        for holding in loaded {
            print("  - \(holding.stock.symbol): qty=\(holding.quantity)")
        }
        holdings = loaded
    }
    
    func clearAllHoldings() {
        print("DEBUG: Clearing all holdings")
        holdings.removeAll()
        persistenceController.clearAllHoldings()
    }
}

// MARK: - Stock Search ViewModel
class StockSearchViewModel: ObservableObject {
    @Published var searchResults: [Stock] = []
    @Published var isSearching = false
    private var cancellables = Set<AnyCancellable>()
    
    func searchStocks(query: String, market: MarketType) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        print("DEBUG: Starting search for '\(query)' in \(market.rawValue) market")
        
        // Try real API
        StockAPIService.shared.searchStocks(query: query, market: market)
            .sink { [weak self] completion in
                self?.isSearching = false
                switch completion {
                case .failure(let error):
                    print("DEBUG: Search API error: \(error.localizedDescription)")
                    // Show error - no mock data
                    self?.searchResults = []
                    print("DEBUG: No results found - connection error")
                case .finished:
                    print("DEBUG: Search completed successfully")
                }
            } receiveValue: { [weak self] stocks in
                self?.searchResults = stocks
                print("DEBUG: Search results: \(stocks.count) stocks found")
            }
            .store(in: &cancellables)
    }
    

}
