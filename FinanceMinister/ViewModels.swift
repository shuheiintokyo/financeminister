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
        
        // Try to fetch real data from Yahoo Finance
        StockAPIService.shared.fetchHistoricalData(symbol: yahooSymbol, market: market)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("DEBUG: Historical data API error: \(error.localizedDescription)")
                    // Fallback to mock data if API fails
                    self?.loadMockHistoricalData(symbol: symbol, market: market)
                case .finished:
                    print("DEBUG: Historical data loaded successfully")
                }
            } receiveValue: { [weak self] prices in
                self?.historicalPrices = prices
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
        
        // Try to fetch real exchange rates
        StockAPIService.shared.fetchExchangeRateHistory()
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("DEBUG: Exchange rate history API error: \(error.localizedDescription)")
                    // Fallback to mock data if API fails
                    self?.loadMockExchangeRateHistory()
                case .finished:
                    print("DEBUG: Exchange rate history loaded successfully")
                }
            } receiveValue: { [weak self] rates in
                self?.historicalExchangeRates = rates
                print("DEBUG: Loaded \(rates.count) exchange rate history points")
                if let firstRate = rates.first, let lastRate = rates.last {
                    print("  - Date range: \(firstRate.date) to \(lastRate.date)")
                    print("  - Rate range: \(firstRate.rate) to \(lastRate.rate)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Fallback Mock Data (if API fails)
    
    private func loadMockHistoricalData(symbol: String, market: MarketType) {
        print("DEBUG: Falling back to mock historical data for \(symbol)")
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
    
    private func loadMockExchangeRateHistory() {
        print("DEBUG: Falling back to mock exchange rate history")
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
        
        // Try real API first
        StockAPIService.shared.searchStocks(query: query, market: market)
            .sink { [weak self] completion in
                self?.isSearching = false
                switch completion {
                case .failure(let error):
                    print("DEBUG: Search API error: \(error.localizedDescription)")
                    // Fallback to mock data on error
                    self?.loadMockData(query: query, market: market)
                case .finished:
                    print("DEBUG: Search completed successfully")
                }
            } receiveValue: { [weak self] stocks in
                self?.searchResults = stocks
                print("DEBUG: Search results: \(stocks.count) stocks found")
            }
            .store(in: &cancellables)
    }
    
    // Fallback mock data if API fails
    private func loadMockData(query: String, market: MarketType) {
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
        
        // Filter by market FIRST
        let stocksForMarket = market == .japanese ? mockJapaneseStocks : mockAmericanStocks
        
        // Then filter by search query
        let filtered = stocksForMarket.filter {
            $0.symbol.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query)
        }
        
        searchResults = filtered
        isSearching = false
        print("DEBUG: Using fallback mock data - \(filtered.count) results")
    }
}
