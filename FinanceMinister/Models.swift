import Foundation

// MARK: - Enums
enum MarketType: String, Codable {
    case japanese = "Japanese"
    case american = "American"
}

enum TimeFrame: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case fiveYears = "5Y"
    
    var displayName: String {
        switch self {
        case .oneWeek: return "1週間"
        case .oneMonth: return "1ヶ月"
        case .threeMonths: return "3ヶ月"
        case .oneYear: return "1年"
        case .fiveYears: return "5年"
        }
    }
}

// MARK: - Stock Data
struct Stock: Identifiable, Codable {
    let id: String
    let symbol: String
    let name: String
    let market: MarketType
    let currentPrice: Double
    let currency: String // JPY or USD
    
    init(id: String, symbol: String, name: String, market: MarketType, currentPrice: Double, currency: String) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.market = market
        self.currentPrice = currentPrice
        self.currency = currency
    }
}

// MARK: - Portfolio Holdings
struct PortfolioHolding: Identifiable, Codable {
    var id: UUID = UUID()
    let stock: Stock
    let quantity: Double
    let purchasePrice: Double
    let purchaseDate: Date
    let account: String
    
    var currentValue: Double {
        stock.currentPrice * quantity
    }
    
    var gainLoss: Double {
        currentValue - (purchasePrice * quantity)
    }
    
    var gainLossPercentage: Double {
        guard purchasePrice > 0 else { return 0 }
        return (gainLoss / (purchasePrice * quantity)) * 100
    }
}

// MARK: - Exchange Rate
struct ExchangeRate: Codable {
    let rate: Double
    let timestamp: Date
    let source: String
}

// MARK: - Historical Price Data
struct PriceHistory: Identifiable, Codable {
    let id: UUID = UUID()
    let date: Date
    let price: Double
    let symbol: String
    let market: MarketType
}

// MARK: - Exchange Rate History
struct ExchangeRateHistory: Identifiable, Codable {
    let id: UUID = UUID()
    let date: Date
    let rate: Double
}

// MARK: - Portfolio Summary
struct PortfolioSummary {
    let totalValueInJpy: Double      // Current total value in Japanese Yen
    let totalCostBasis: Double       // Total amount invested (cost basis)
    let holdings: [PortfolioHolding]
}
