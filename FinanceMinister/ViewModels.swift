import Foundation
import Combine
import CoreData

// MARK: - Updated Portfolio View Model
class PortfolioViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var holdings: [PortfolioHolding] = []
    @Published var totalPortfolioValue: Double = 0.0
    @Published var currentExchangeRate: Double = 155.0
    @Published var isAuthenticated = true
    @Published var isLoading = false
    @Published var portfolioHistory: [PortfolioSnapshot] = []
    @Published var portfolioSummary: PortfolioSummary = PortfolioSummary(totalValueInJpy: 0, totalCostBasis: 0, holdings: [])
    
    // MARK: - Public Properties
    var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Private Properties
    private let backendAPIService = BackendAPIService.shared  // Vercel backend
    private let stockAPIService = StockAPIService.shared      // Fallback for search
    private let viewContext = PersistenceController.shared.container.viewContext
    private var autoRefreshTimer: Timer?
    
    override init() {
        super.init()
        loadHoldings()
        loadPortfolioHistory()
        refreshPortfolio()
        startAutoRefresh(intervalSeconds: 300) // Auto-refresh every 5 minutes
    }
    
    deinit {
        autoRefreshTimer?.invalidate()
    }
    
    // MARK: - Refresh Portfolio (Main Entry Point)
    func refreshPortfolio() {
        print("🔄 Refreshing portfolio...")
        fetchExchangeRate()
        updateStockPrices()
    }
    
    // MARK: - Load Holdings from Core Data
    func loadHoldings() {
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HoldingEntity.id, ascending: true)]
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            self.holdings = entities.map { entity in
                let stock = Stock(
                    id: entity.id?.uuidString ?? "",
                    symbol: entity.symbol ?? "",
                    name: entity.stockName ?? "",
                    market: entity.marketType == "japanese" ? .japanese : .american,
                    currentPrice: entity.currentPrice,
                    currency: entity.currency ?? "USD"
                )
                
                return PortfolioHolding(
                    id: entity.id ?? UUID(),
                    stock: stock,
                    quantity: entity.quantity,
                    purchasePrice: entity.purchasePrice,
                    purchaseDate: entity.purchaseDate ?? Date(),
                    account: entity.account ?? "Default"
                )
            }
            print("📂 Loaded \(self.holdings.count) holdings from Core Data")
        } catch {
            print("❌ Error loading holdings: \(error)")
        }
        
        updatePortfolioSummary()
    }
    
    // MARK: - Load Portfolio History from Core Data
    func loadPortfolioHistory() {
        let fetchRequest: NSFetchRequest<PortfolioSnapshotEntity> = PortfolioSnapshotEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PortfolioSnapshotEntity.date, ascending: true)]
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            self.portfolioHistory = entities.compactMap { entity in
                guard let id = entity.id,
                      let date = entity.date else { return nil }
                return PortfolioSnapshot(date: date, totalValue: entity.totalvalue)
            }
            print("📈 Loaded \(self.portfolioHistory.count) portfolio history snapshots")
        } catch {
            print("❌ Error loading portfolio history: \(error)")
        }
    }
    
    // MARK: - Add Holding (Compatible with existing code)
    func addHolding(_ holding: PortfolioHolding) {
        holdings.append(holding)
        
        // Save to Core Data
        let entity = HoldingEntity(context: viewContext)
        entity.id = holding.id
        entity.symbol = holding.stock.symbol
        entity.stockName = holding.stock.name
        entity.marketType = holding.stock.market == .japanese ? "japanese" : "american"
        entity.currentPrice = holding.stock.currentPrice
        entity.currency = holding.stock.currency
        entity.quantity = holding.quantity
        entity.purchasePrice = holding.purchasePrice
        entity.purchaseDate = holding.purchaseDate
        entity.account = holding.account
        
        do {
            try viewContext.save()
            print("✅ Added holding: \(holding.stock.symbol)")
        } catch {
            print("❌ Error saving holding: \(error)")
        }
        
        updatePortfolioSummary()
        updateStockPrices()
    }
    
    // MARK: - Remove Holding
    func removeHolding(_ holding: PortfolioHolding) {
        holdings.removeAll { $0.id == holding.id }
        
        // Delete from Core Data
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", holding.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            for entity in results {
                viewContext.delete(entity)
            }
            try viewContext.save()
            print("✅ Removed holding: \(holding.stock.symbol)")
        } catch {
            print("❌ Error deleting holding: \(error)")
        }
        
        updatePortfolioSummary()
    }
    
    // MARK: - Update Stock Prices (Using Vercel Backend with Batch Endpoint)
    private func updateStockPrices() {
        isLoading = true
        print("📊 Updating stock prices from Vercel backend...")
        
        guard !holdings.isEmpty else {
            isLoading = false
            return
        }
        
        // Prepare batch request
        let symbolsWithMarkets = holdings.map { (symbol: $0.stock.symbol, market: $0.stock.market.rawValue) }
        
        // Use batch endpoint for efficiency
        backendAPIService.fetchMultipleStockPrices(symbols: symbolsWithMarkets)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Batch price fetch failed: \(error)")
                    }
                    self?.isLoading = false
                },
                receiveValue: { [weak self] prices in
                    guard let self = self else { return }
                    
                    // Update holdings with new prices
                    for price in prices {
                        if let index = self.holdings.firstIndex(where: { $0.stock.symbol == price.symbol }) {
                            var updatedHolding = self.holdings[index]
                            
                            let updatedStock = Stock(
                                id: updatedHolding.stock.id,
                                symbol: updatedHolding.stock.symbol,
                                name: updatedHolding.stock.name,
                                market: updatedHolding.stock.market,
                                currentPrice: price.price,
                                currency: price.currency
                            )
                            
                            updatedHolding = PortfolioHolding(
                                id: updatedHolding.id,
                                stock: updatedStock,
                                quantity: updatedHolding.quantity,
                                purchasePrice: updatedHolding.purchasePrice,
                                purchaseDate: updatedHolding.purchaseDate,
                                account: updatedHolding.account
                            )
                            
                            self.holdings[index] = updatedHolding
                            
                            // Update in Core Data
                            self.updateCoreData(for: updatedHolding, newPrice: price.price)
                            
                            print("✅ Updated \(updatedHolding.stock.symbol): \(price.price) \(price.currency)")
                        }
                    }
                    
                    self.updatePortfolioSummary()
                    self.recordPortfolioSnapshot()
                    self.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Update Core Data for Holding
    private func updateCoreData(for holding: PortfolioHolding, newPrice: Double) {
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", holding.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let entity = results.first {
                entity.currentPrice = newPrice
                try viewContext.save()
            }
        } catch {
            print("❌ Error updating Core Data: \(error)")
        }
    }
    
    // MARK: - Fetch Exchange Rate (Using Vercel Backend)
    func fetchExchangeRate() {
        print("💱 Fetching exchange rate from Vercel backend...")
        
        backendAPIService.fetchExchangeRate()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("⚠️ Exchange rate error: \(error)")
                }
            } receiveValue: { [weak self] rate in
                self?.currentExchangeRate = rate
                print("✅ Exchange rate: \(rate) JPY/USD")
                self?.updatePortfolioSummary()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Update Portfolio Summary
    private func updatePortfolioSummary() {
        var totalValueInJpy: Double = 0
        var totalCostBasis: Double = 0
        
        for holding in holdings {
            let holdingValue = holding.stock.currentPrice * holding.quantity
            
            // Convert to JPY if USD
            let holdingValueInJpy = holding.stock.market == .american ?
                holdingValue * currentExchangeRate :
                holdingValue
            
            totalValueInJpy += holdingValueInJpy
            
            // Cost basis (always in JPY for consistency)
            let costInJpy = holding.purchasePrice * holding.quantity
            totalCostBasis += costInJpy
        }
        
        self.totalPortfolioValue = totalValueInJpy
        
        self.portfolioSummary = PortfolioSummary(
            totalValueInJpy: totalValueInJpy,
            totalCostBasis: totalCostBasis,
            holdings: holdings
        )
        
        print("💼 Portfolio: ¥\(String(format: "%.0f", totalValueInJpy)) (\(holdings.count) holdings)")
    }
    
    // MARK: - Record Portfolio Snapshot
    func recordPortfolioSnapshot() {
        let snapshot = PortfolioSnapshot(
            date: Date(),
            totalValue: totalPortfolioValue
        )
        portfolioHistory.append(snapshot)
        
        // Keep only last 90 data points
        if portfolioHistory.count > 90 {
            portfolioHistory.removeFirst()
        }
        
        // Save to Core Data
        let entity = PortfolioSnapshotEntity(context: viewContext)
        entity.id = snapshot.id
        entity.date = snapshot.date
        entity.totalvalue = snapshot.totalValue
        
        do {
            try viewContext.save()
            print("💾 Snapshot saved: ¥\(String(format: "%.0f", snapshot.totalValue))")
        } catch {
            print("❌ Error saving snapshot: \(error)")
        }
    }
    
    // MARK: - Clear All Holdings
    func clearAllHoldings() {
        holdings.removeAll()
        
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            for entity in results {
                viewContext.delete(entity)
            }
            try viewContext.save()
            print("✅ Cleared all holdings")
        } catch {
            print("❌ Error clearing holdings: \(error)")
        }
        
        updatePortfolioSummary()
    }
    
    // MARK: - Save Portfolio (Alias for saveContext)
    func savePortfolio() {
        do {
            try viewContext.save()
            print("💾 Portfolio saved to Core Data")
        } catch {
            print("❌ Error saving portfolio: \(error)")
        }
    }
    
    // MARK: - Auto-refresh Portfolio (Called periodically)
    func startAutoRefresh(intervalSeconds: TimeInterval = 300) {
        print("⏰ Starting auto-refresh every \(Int(intervalSeconds)) seconds")
        
        // Initial refresh
        refreshPortfolio()
        
        // Schedule periodic refresh (every 5 minutes by default)
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.refreshPortfolio()
        }
    }
    
    // MARK: - Stop Auto-refresh
    func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        print("⏹️ Auto-refresh stopped")
    }
    
    // MARK: - Full Sync (Prices + Exchange Rate)
    func fullSync() {
        print("🔄 Running full portfolio sync...")
        fetchExchangeRate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateStockPrices()
        }
    }
    
    // MARK: - Update Total Portfolio Value (Helper)
    func updateTotalPortfolioValue() {
        updatePortfolioSummary()
    }
}

// MARK: - Helper Function
func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
