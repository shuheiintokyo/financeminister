import Foundation
import Combine

class NetworkService {
    static let shared = NetworkService()
    private init() {}
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Fetch Exchange Rate (Real API)
    func fetchExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        print("DEBUG: Fetching exchange rate from Yahoo Finance")
        
        // Fetch from Yahoo Finance API
        return StockAPIService.shared.fetchExchangeRateHistory()
            .tryMap { rates in
                // Get the latest rate
                guard let latestRate = rates.last else {
                    throw URLError(.badServerResponse)
                }
                
                return ExchangeRate(
                    rate: latestRate.rate,
                    timestamp: latestRate.date,
                    source: "Yahoo Finance"
                )
            }
            .catch { error -> AnyPublisher<ExchangeRate, Error> in
                print("DEBUG: Failed to fetch exchange rate: \(error)")
                // Fallback to fixed rate if API fails
                let fallbackRate = ExchangeRate(
                    rate: 149.50,
                    timestamp: Date(),
                    source: "Fixed (API failed)"
                )
                return Just(fallbackRate)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Stock Price (Public - No Auth Required)
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Stock, Error> {
        print("DEBUG: Fetching stock price for \(symbol)")
        
        // Use public API endpoint (no token needed, works with headers)
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
                print("DEBUG: Stock price fetch failed: \(error)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Check Authentication Status
    func isAuthenticated() -> Bool {
        return YahooOAuth2Manager.shared.isAuthenticated
    }
    
    // MARK: - Refresh Token if Needed
    func refreshTokenIfNeeded() -> AnyPublisher<Void, Error> {
        if YahooOAuth2Manager.shared.isTokenExpired() {
            print("DEBUG: Token expired, need to re-authenticate")
            return Fail(error: URLError(.userAuthenticationRequired))
                .eraseToAnyPublisher()
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
