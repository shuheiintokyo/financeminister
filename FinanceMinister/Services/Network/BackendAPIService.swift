import Foundation
import Combine

// MARK: - Backend API Service (Vercel)
class BackendAPIService {
    static let shared = BackendAPIService()
    
    // Configuration
    private let baseURL = "https://backendindex.vercel.app"
    private let session: URLSession
    
    // Cache
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private var exchangeRateCache: (rate: Double, timestamp: Date)?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Fetch Stock Price (Compatible with existing code)
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Double, Error> {
        // Check cache
        if let cached = priceCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("✅ Using cached price for \(symbol): \(cached.price)")
            return Just(cached.price)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        print("📡 Fetching price for \(symbol) from Vercel backend")
        
        let marketString = market == .japanese ? "japanese" : "american"
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/stock/price") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "market", value: marketString)
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BackendStockPrice.self, decoder: JSONDecoder())
            .tryMap { stockPrice -> Double in
                let price = stockPrice.price
                self.priceCache[symbol] = (price: price, timestamp: Date())
                print("✅ Got price for \(symbol): \(price) \(stockPrice.currency)")
                return price
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("❌ Error fetching price: \(error.localizedDescription)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Exchange Rate
    func fetchExchangeRate() -> AnyPublisher<Double, Error> {
        // Check cache
        if let cached = exchangeRateCache,
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("✅ Using cached exchange rate: \(cached.rate)")
            return Just(cached.rate)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        print("💱 Fetching exchange rate from Vercel backend")
        
        guard let url = URL(string: "\(baseURL)/api/exchange-rate") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BackendExchangeRate.self, decoder: JSONDecoder())
            .tryMap { exchangeRate -> Double in
                let rate = Double(exchangeRate.exchange_rate) ?? 0
                self.exchangeRateCache = (rate: rate, timestamp: Date())
                print("✅ Got exchange rate: \(rate) JPY/USD")
                return rate
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("⚠️ Exchange rate fetch failed: \(error.localizedDescription)")
                // Fallback to reasonable rate
                return Just(155.0)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Search Stocks
    func searchStocks(query: String, market: MarketType) -> AnyPublisher<[Stock], Error> {
        print("🔍 Searching for '\(query)' via Vercel backend")
        
        // For now, return empty - backend doesn't have search yet
        // This keeps compatibility with your existing code
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        priceCache.removeAll()
        exchangeRateCache = nil
        print("🗑️ Cache cleared")
    }
}

// MARK: - Backend Response Models
struct BackendStockPrice: Codable {
    let symbol: String
    let name: String
    let price: Double
    let currency: String
    let market: String
    let source: String
    let change: Double?
    let changePercent: Double?
    let high: Double?
    let low: Double?
    let volume: Int?
    let timestamp: String
}

struct BackendExchangeRate: Codable {
    let from_currency: String
    let to_currency: String
    let exchange_rate: String
}
}
