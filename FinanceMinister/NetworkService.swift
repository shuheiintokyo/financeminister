import Foundation
import Combine

class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    func fetchExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        let mockRate = ExchangeRate(
            rate: 149.50,
            timestamp: Date(),
            source: "Mock"
        )
        return Just(mockRate)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Stock, Error> {
        let stock = Stock(
            id: symbol,
            symbol: symbol,
            name: symbol,
            market: market,
            currentPrice: market == .american ? 150.0 : 5000.0,
            currency: market == .american ? "USD" : "JPY"
        )
        return Just(stock)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
