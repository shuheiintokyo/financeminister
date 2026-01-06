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
    @Published var isAuthenticated = true  // No auth needed with Alpha Vantage!
    
    private var cancellables = Set<AnyCancellable>()
    private let persistenceController = PersistenceController.shared
    
    init() {
        loadHoldings()
        refreshExchangeRate()
        print("✅ PortfolioViewModel initialized - No OAuth needed!")
    }
    
    // MARK: - Portfolio Management
    
    func addHolding(_ holding: PortfolioHolding) {
        print("📝 Adding holding - \(holding.stock.symbol), qty: \(holding.quantity)")
        holdings.append(holding)
        persistenceController.saveHolding(holding)
        refreshStockPrices()
    }
    
    func removeHolding(_ holding: PortfolioHolding) {
        print("🗑️ Removing holding - \(holding.stock.symbol)")
        holdings.removeAll { $0.id == holding.id }
        persistenceController.deleteHolding(holding)
    }
    
    func updateHolding(_ holding: PortfolioHolding) {
        if let index = holdings.firstIndex(where: { $0.id == holding.id }) {
            holdings[index] = holding
            persistenceController.saveHolding(holding)
        }
    }
    
    // MARK: - Portfolio Summary
    
    var portfolioSummary: PortfolioSummary {
        var totalValueInJpy: Double = 0
        var totalCostBasis: Double = 0
        
        for holding in holdings {
            let valueInJpy: Double
            let costInJpy: Double
            
            if holding.stock.market == .american {
                valueInJpy = holding.currentValue * currentExchangeRate
                costInJpy = (holding.purchasePrice * holding.quantity) * currentExchangeRate
            } else {
                valueInJpy = holding.currentValue
                costInJpy = holding.purchasePrice * holding.quantity
            }
            
            totalValueInJpy += valueInJpy
            totalCostBasis += costInJpy
        }
        
        print("💼 Portfolio Summary - Value: ¥\(totalValueInJpy), Holdings: \(holdings.count)")
        
        return PortfolioSummary(
            totalValueInJpy: totalValueInJpy,
            totalCostBasis: totalCostBasis,
            holdings: holdings
        )
    }
    
    // MARK: - Data Refreshing
    
    func refreshPortfolio() {
        print("🔄 Refreshing portfolio...")
        isLoading = true
        refreshExchangeRate()
        refreshStockPrices()
        isLoading = false
    }
    
    func refreshExchangeRate() {
        print("💱 Fetching current USD/JPY exchange rate...")
        
        StockAPIService.shared.fetchExchangeRate()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("⚠️ Exchange rate fetch failed: \(error)")
                case .finished:
                    print("✅ Exchange rate updated")
                }
            } receiveValue: { [weak self] rate in
                self?.currentExchangeRate = rate
                print("💱 USD/JPY: \(rate)")
            }
            .store(in: &cancellables)
    }
    
    private func refreshStockPrices() {
        print("📊 Refreshing stock prices for \(holdings.count) holdings...")
        
        for holding in holdings {
            StockAPIService.shared.fetchStockPrice(symbol: holding.stock.symbol, market: holding.stock.market)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("⚠️ Error fetching \(holding.stock.symbol): \(error)")
                    }
                } receiveValue: { [weak self] price in
                    if let index = self?.holdings.firstIndex(where: { $0.stock.symbol == holding.stock.symbol }) {
                        // Create new stock with updated price
                        var currentHolding = self?.holdings[index]
                        let updatedStock = Stock(
                            id: currentHolding?.stock.id ?? "",
                            symbol: currentHolding?.stock.symbol ?? "",
                            name: currentHolding?.stock.name ?? "",
                            market: currentHolding?.stock.market ?? .american,
                            currentPrice: price,
                            currency: currentHolding?.stock.currency ?? "USD"
                        )
                        
                        // Create new holding with updated stock
                        let updatedHolding = PortfolioHolding(
                            id: currentHolding?.id ?? UUID(),
                            stock: updatedStock,
                            quantity: currentHolding?.quantity ?? 0,
                            purchasePrice: currentHolding?.purchasePrice ?? 0,
                            purchaseDate: currentHolding?.purchaseDate ?? Date(),
                            account: currentHolding?.account ?? "Default"
                        )
                        
                        self?.holdings[index] = updatedHolding
                        print("✅ Updated \(holding.stock.symbol): $\(price)")
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    func loadHistoricalData(for symbol: String, market: MarketType) {
        print("📈 Loading historical data for \(symbol)")
        
        StockAPIService.shared.fetchHistoricalData(symbol: symbol, market: market)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("⚠️ Historical data error: \(error)")
                }
            } receiveValue: { [weak self] prices in
                self?.historicalPrices = prices
                print("📊 Loaded \(prices.count) historical data points")
            }
            .store(in: &cancellables)
    }
    
    func loadExchangeRateHistory() {
        print("📈 Loading exchange rate history")
        
        StockAPIService.shared.fetchExchangeRateHistory()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("⚠️ Exchange rate history error: \(error)")
                }
            } receiveValue: { [weak self] rates in
                self?.historicalExchangeRates = rates
                print("💱 Loaded \(rates.count) exchange rate history points")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Persistence
    
    func loadHoldings() {
        let loaded = persistenceController.loadHoldings()
        print("📂 Loaded \(loaded.count) holdings from Core Data")
        holdings = loaded
    }
    
    func clearAllHoldings() {
        print("🗑️ Clearing all holdings")
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
        print("🔍 Searching for '\(query)'")
        
        StockAPIService.shared.searchStocks(query: query, market: market)
            .sink { [weak self] completion in
                self?.isSearching = false
                switch completion {
                case .failure(let error):
                    print("❌ Search error: \(error)")
                    self?.searchResults = []
                case .finished:
                    print("✅ Search completed")
                }
            } receiveValue: { [weak self] stocks in
                self?.searchResults = stocks
                print("✅ Found \(stocks.count) results")
            }
            .store(in: &cancellables)
    }
}
