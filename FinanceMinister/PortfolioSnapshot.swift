import Foundation

// MARK: - Portfolio Snapshot Model
struct PortfolioSnapshot: Identifiable, Codable {
    let id: UUID
    let date: Date
    let totalValue: Double  // in JPY
    
    init(date: Date = Date(), totalValue: Double) {
        self.id = UUID()
        self.date = date
        self.totalValue = totalValue
    }
}
