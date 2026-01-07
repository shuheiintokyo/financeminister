import Foundation
import Combine

class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Fetch Exchange Rate (Real API)
    func fetchExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        print("💱 Fetching exchange rate from Alpha Vantage")
        
        // Use direct API call instead of history (which is empty in free tier)
        return StockAPIService.shared.fetchExchangeRate()
            .map { rate in
                ExchangeRate(
                    rate: rate,
                    timestamp: Date(),
                    source: "Alpha Vantage"
                )
            }
            .catch { error -> AnyPublisher<ExchangeRate, Error> in
                print("⚠️ Failed to fetch exchange rate: \(error)")
                // Fallback to reasonable rate if API fails
                let fallbackRate = ExchangeRate(
                    rate: 149.50,
                    timestamp: Date(),
                    source: "Fallback (API unavailable)"
                )
                return Just(fallbackRate)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Stock Price (Public - No Auth Required)
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Stock, Error> {
        print("📊 Fetching stock price for \(symbol)")
        
        // Use Alpha Vantage API
        return StockAPIService.shared.fetchStockPrice(symbol: symbol, market: market)
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
            .catch { error -> AnyPublisher<Stock, Error> in
                print("❌ Stock price fetch failed: \(error)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
