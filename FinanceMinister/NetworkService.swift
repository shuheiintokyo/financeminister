import Foundation
import Combine

class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    func fetchExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        // For now, use fixed rate. In production, you could fetch from Yahoo Finance
        let mockRate = ExchangeRate(
            rate: 149.50,
            timestamp: Date(),
            source: "Fixed"
        )
        return Just(mockRate)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Stock, Error> {
        // Use real Yahoo Finance API
        StockAPIService.shared.fetchStockPrice(symbol: symbol, market: market)
            .map { price in
                Stock(
                    id: symbol,
                    symbol: symbol,
                    name: symbol,
                    market: market,
                    currentPrice: price,
                    currency: market == .american ? "USD" : "JPY"
                )
            }
            .eraseToAnyPublisher()
    }
}
