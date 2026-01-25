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
    private let backendAPIService = BackendAPIService.shared  // NEW: Using Vercel backend
    private let stockAPIService = StockAPIService.shared      // FALLBACK: Keep for compatibility
    private let viewContext = PersistenceController.shared.container.viewContext
    
    override init() {
        super.init()
        loadHoldings()
        loadPortfolioHistory()
        refreshPortfolio()
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
    
    // MARK: - Update Stock Prices (Using Vercel Backend)
    private func updateStockPrices() {
        isLoading = true
        print("📊 Updating stock prices from Vercel backend...")
        
        let publishers = holdings.map { holding in
            backendAPIService.fetchStockPrice(symbol: holding.stock.symbol, market: holding.stock.market)
                .map { price -> (UUID, Double) in
                    (holding.id, price)
                }
                .catch { error -> AnyPublisher<(UUID, Double), Never> in
                    print("⚠️ Failed to fetch \(holding.stock.symbol), keeping cached price")
                    return Just((holding.id, holding.stock.currentPrice))
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        if publishers.isEmpty {
            isLoading = false
            return
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                for (holdingId, price) in results {
                    if let index = self?.holdings.firstIndex(where: { $0.id == holdingId }) {
                        guard let self = self else { return }
                        var updatedHolding = self.holdings[index]
                        
                        let updatedStock = Stock(
                            id: updatedHolding.stock.id,
                            symbol: updatedHolding.stock.symbol,
                            name: updatedHolding.stock.name,
                            market: updatedHolding.stock.market,
                            currentPrice: price,
                            currency: updatedHolding.stock.currency
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
                        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", holdingId as CVarArg)
                        
                        do {
                            let results = try self.viewContext.fetch(fetchRequest)
                            if let entity = results.first {
                                entity.currentPrice = price
                                try self.viewContext.save()
                            }
                        } catch {
                            print("❌ Error updating Core Data: \(error)")
                        }
                        
                        print("✅ Updated \(updatedHolding.stock.symbol): \(price)")
                    }
                }
                
                self?.updatePortfolioSummary()
                self?.recordPortfolioSnapshot()
                self?.isLoading = false
            }
            .store(in: &cancellables)
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
            
            // Cost basis (always in JPY)
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
}

// MARK: - Helper Function
func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
