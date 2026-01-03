import Foundation
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    private init() {
        container = NSPersistentContainer(name: "FinanceMinister")
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                print("Core Data load error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Holding Operations
    
    func saveHolding(_ holding: PortfolioHolding) {
        let context = container.viewContext
        let entity = HoldingEntity(context: context)
        
        print("DEBUG: Saving holding")
        print("  - id: \(holding.id)")
        print("  - symbol: \(holding.stock.symbol)")
        print("  - quantity: \(holding.quantity)")
        print("  - purchasePrice: \(holding.purchasePrice)")
        
        entity.id = holding.id
        entity.quantity = holding.quantity
        entity.purchasePrice = holding.purchasePrice
        entity.purchaseDate = holding.purchaseDate
        entity.account = holding.account
        entity.symbol = holding.stock.symbol
        entity.stockName = holding.stock.name
        entity.marketType = holding.stock.market.rawValue
        entity.currentPrice = holding.stock.currentPrice
        entity.currency = holding.stock.currency
        
        print("  - Entity saved: quantity=\(entity.quantity), purchasePrice=\(entity.purchasePrice)")
        
        save(context)
    }
    
    func loadHoldings() -> [PortfolioHolding] {
        let context = container.viewContext
        let fetchRequest = HoldingEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { entity in
                print("DEBUG: Loading HoldingEntity")
                print("  - id: \(entity.id ?? UUID())")
                print("  - symbol: \(entity.symbol ?? "nil")")
                print("  - quantity: \(entity.quantity)")
                print("  - purchasePrice: \(entity.purchasePrice)")
                
                let market = MarketType(rawValue: entity.marketType ?? "Japanese") ?? .japanese
                let stock = Stock(
                    id: entity.symbol ?? "",
                    symbol: entity.symbol ?? "",
                    name: entity.stockName ?? "",
                    market: market,
                    currentPrice: entity.currentPrice,
                    currency: entity.currency ?? "JPY"
                )
                
                let holding = PortfolioHolding(
                    id: entity.id ?? UUID(),
                    stock: stock,
                    quantity: entity.quantity,
                    purchasePrice: entity.purchasePrice,
                    purchaseDate: entity.purchaseDate ?? Date(),
                    account: entity.account ?? "Default"
                )
                
                print("  - Created holding with quantity: \(holding.quantity)")
                return holding
            }
        } catch {
            print("Failed to fetch holdings: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteHolding(_ holding: PortfolioHolding) {
        let context = container.viewContext
        let fetchRequest = HoldingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", holding.id as CVarArg)
        
        do {
            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
                save(context)
            }
        } catch {
            print("Failed to delete holding: \(error.localizedDescription)")
        }
    }
    
    func clearAllHoldings() {
        let context = container.viewContext
        let fetchRequest = HoldingEntity.fetchRequest()
        
        do {
            let holdings = try context.fetch(fetchRequest)
            holdings.forEach { context.delete($0) }
            save(context)
        } catch {
            print("Failed to clear holdings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper
    
    private func save(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Save error: \(nsError.localizedDescription)")
            }
        }
    }
}

// NOTE: HoldingEntity is auto-generated from your .xcdatamodel file
// Xcode will automatically generate the HoldingEntity class and fetchRequest()
// Do NOT manually define the class here, as it will conflict with code generation
