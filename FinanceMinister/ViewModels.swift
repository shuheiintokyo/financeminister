import Foundation
import Combine
import CoreData

// MARK: - Portfolio View Model
class PortfolioViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var holdings: [PortfolioHolding] = []
    @Published var totalPortfolioValue: Double = 0.0
    @Published var exchangeRate: Double = 149.50
    @Published var isAuthenticated = true
    @Published var isLoading = false
    @Published var portfolioHistory: [PortfolioSnapshot] = []
    
    // MARK: - Public Properties
    var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Private Properties
    private let stockAPIService = StockAPIService.shared
    
    override init() {
        super.init()
        loadHoldings()
        loadPortfolioHistory()
        fetchExchangeRate()
        updateStockPrices()
    }
    
    // MARK: - Load Holdings from Core Data
    func loadHoldings() {
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HoldingEntity.id, ascending: true)]
        
        do {
            let entities = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
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
        
        updatePortfolioValue()
    }
    
    // MARK: - Load Portfolio History from Core Data
    func loadPortfolioHistory() {
        let fetchRequest: NSFetchRequest<PortfolioSnapshotEntity> = PortfolioSnapshotEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PortfolioSnapshotEntity.date, ascending: true)]
        
        do {
            let entities = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            self.portfolioHistory = entities.compactMap { entity in
                guard let id = entity.id,
                      let date = entity.date else { return nil }
                return PortfolioSnapshot(date: date, totalValue: entity.totalValue)
            }
            print("📈 Loaded \(self.portfolioHistory.count) portfolio history snapshots")
        } catch {
            print("❌ Error loading portfolio history: \(error)")
        }
    }
    
    // MARK: - Record Portfolio Snapshot
    func recordPortfolioSnapshot() {
        let snapshot = PortfolioSnapshot(
            date: Date(),
            totalValue: totalPortfolioValue
        )
        portfolioHistory.append(snapshot)
        
        // Keep only last 90 data points (3 months of daily data)
        if portfolioHistory.count > 90 {
            portfolioHistory.removeFirst()
        }
        
        // Save to Core Data
        let entity = PortfolioSnapshotEntity(context: PersistenceController.shared.container.viewContext)
        entity.id = snapshot.id
        entity.date = snapshot.date
        entity.totalValue = snapshot.totalValue
        
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("💾 Saved portfolio snapshot: ¥\(String(format: "%.0f", snapshot.totalValue))")
        } catch {
            print("❌ Error saving snapshot: \(error)")
        }
    }
    
    // MARK: - Add Holding
    func addHolding(stock: Stock, quantity: Double, purchasePrice: Double) {
        let holding = PortfolioHolding(
            id: UUID(),
            stock: stock,
            quantity: quantity,
            purchasePrice: purchasePrice,
            purchaseDate: Date(),
            account: "Default"
        )
        
        holdings.append(holding)
        
        // Save to Core Data
        let entity = HoldingEntity(context: PersistenceController.shared.container.viewContext)
        entity.id = holding.id
        entity.symbol = stock.symbol
        entity.stockName = stock.name
        entity.marketType = stock.market == .japanese ? "japanese" : "american"
        entity.currentPrice = stock.currentPrice
        entity.currency = stock.currency
        entity.quantity = quantity
        entity.purchasePrice = purchasePrice
        entity.purchaseDate = Date()
        entity.account = "Default"
        
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("📝 Adding holding - \(stock.symbol), qty: \(quantity)")
        } catch {
            print("❌ Error saving holding: \(error)")
        }
        
        updatePortfolioValue()
        updateStockPrices()
    }
    
    // MARK: - Remove Holding
    func removeHolding(id: UUID) {
        holdings.removeAll { $0.id == id }
        
        // Delete from Core Data
        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            for entity in results {
                PersistenceController.shared.container.viewContext.delete(entity)
            }
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("❌ Error deleting holding: \(error)")
        }
        
        updatePortfolioValue()
    }
    
    // MARK: - Update Stock Prices
    func updateStockPrices() {
        print("📊 Refreshing stock prices for \(holdings.count) holdings...")
        
        let publishers = holdings.map { holding in
            stockAPIService.fetchStockPrice(symbol: holding.stock.symbol, market: holding.stock.market)
                .map { price -> (UUID, Double) in
                    (holding.id, price)
                }
                .catch { error -> AnyPublisher<(UUID, Double), Never> in
                    print("❌ Failed to fetch price for \(holding.stock.symbol): \(error)")
                    return Just((holding.id, holding.stock.currentPrice))
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        if publishers.isEmpty {
            return
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                for (holdingId, price) in results {
                    if let index = self?.holdings.firstIndex(where: { $0.id == holdingId }) {
                        var updatedHolding = self!.holdings[index]
                        
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
                        
                        self?.holdings[index] = updatedHolding
                        
                        // Update in Core Data
                        let fetchRequest: NSFetchRequest<HoldingEntity> = HoldingEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", holdingId as CVarArg)
                        
                        do {
                            let results = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
                            if let entity = results.first {
                                entity.currentPrice = price
                                try PersistenceController.shared.container.viewContext.save()
                            }
                        } catch {
                            print("❌ Error updating price in Core Data: \(error)")
                        }
                        
                        print("✅ Updated \(updatedHolding.stock.symbol): $\(price)")
                    }
                }
                
                self?.updatePortfolioValue()
                self?.recordPortfolioSnapshot()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Fetch Exchange Rate
    func fetchExchangeRate() {
        print("💱 Fetching current USD/JPY exchange rate...")
        
        stockAPIService.fetchExchangeRate()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("❌ Exchange rate error: \(error)")
                }
            } receiveValue: { [weak self] rate in
                self?.exchangeRate = rate
                print("💱 USD/JPY: \(rate)")
                print("✅ Exchange rate updated")
                self?.updatePortfolioValue()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Update Portfolio Value
    private func updatePortfolioValue() {
        var totalValue: Double = 0
        
        for holding in holdings {
            let holdingValue = holding.stock.currentPrice * holding.quantity * exchangeRate
            totalValue += holdingValue
        }
        
        self.totalPortfolioValue = totalValue
        print("💼 Portfolio Summary - Value: ¥\(String(format: "%.1f", totalValue)), Holdings: \(holdings.count)")
    }
    
    // MARK: - Load Historical Data
    func loadHistoricalData() {
        print("📈 Loading historical data...")
        
        for holding in holdings {
            stockAPIService.fetchHistoricalData(symbol: holding.stock.symbol, market: holding.stock.market)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        print("❌ Historical data error: \(error)")
                    }
                } receiveValue: { data in
                    print("📊 Loaded \(data.count) historical data points")
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Load Exchange Rate History
    func loadExchangeRateHistory() {
        print("📈 Loading exchange rate history")
        
        stockAPIService.fetchExchangeRateHistory()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("❌ Exchange rate history error: \(error)")
                }
            } receiveValue: { history in
                print("💱 Loaded \(history.count) exchange rate history points")
            }
            .store(in: &cancellables)
    }
}
