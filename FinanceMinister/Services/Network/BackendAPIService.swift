import Foundation
import Combine

// MARK: - Backend API Service (Vercel)
class BackendAPIService {
    static let shared = BackendAPIService()
    
    private let baseURL = "https://backendindex.vercel.app"
    private var priceCache: [String: CachedPrice] = [:]
    private let cacheDuration: TimeInterval = 15 * 60 // 15 minutes
    
    private struct CachedPrice {
        let price: Double
        let timestamp: Date
        let currency: String
    }
    
    // MARK: - Fetch Single Stock Price
    func fetchStockPrice(symbol: String, market: String = "american") -> AnyPublisher<StockPrice, Error> {
        print("📡 Fetching price for \(symbol) from Vercel backend")
        
        // Check cache first
        if let cached = priceCache[symbol], Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            print("💾 Using cached price for \(symbol): \(cached.price)")
            return Just(StockPrice(
                symbol: symbol,
                name: symbol,
                price: cached.price,
                currency: cached.currency,
                market: market,
                cached: true
            ))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        }
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/stock/price") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "market", value: market)
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BackendStockPrice.self, decoder: JSONDecoder())
            .tryMap { backendPrice in
                // Cache the result
                self.priceCache[symbol] = CachedPrice(
                    price: backendPrice.price,
                    timestamp: Date(),
                    currency: backendPrice.currency
                )
                
                print("✅ Got price for \(symbol): \(backendPrice.price) \(backendPrice.currency)")
                
                return StockPrice(
                    symbol: symbol,
                    name: backendPrice.name ?? symbol,
                    price: backendPrice.price,
                    currency: backendPrice.currency,
                    market: market,
                    cached: backendPrice.cached ?? false
                )
            }
            .catch { error -> AnyPublisher<StockPrice, Error> in
                print("❌ Stock price fetch failed: \(error)")
                return Fail(error: error)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Multiple Stock Prices (Batch)
    func fetchMultipleStockPrices(symbols: [(symbol: String, market: String)]) -> AnyPublisher<[StockPrice], Error> {
        print("📡 Batch fetching \(symbols.count) stocks from Vercel")
        
        guard let url = URL(string: "\(baseURL)/api/stocks/batch") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        let body: [String: [[String: String]]] = [
            "symbols": symbols.map { ["symbol": $0.symbol, "market": $0.market] }
        ]
        
        guard let jsonData = try? JSONEncoder().encode(body) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: BatchStockResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                let prices = response.stocks.map { backendStock in
                    StockPrice(
                        symbol: backendStock.symbol,
                        name: backendStock.name ?? backendStock.symbol,
                        price: backendStock.price,
                        currency: backendStock.currency ?? "USD",
                        market: backendStock.market ?? "american",
                        cached: false
                    )
                }
                print("✅ Batch fetch completed: \(prices.count) stocks")
                return prices
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Exchange Rate
    func fetchExchangeRate() -> AnyPublisher<Double, Error> {
        print("💱 Fetching exchange rate from Vercel")
        
        guard let url = URL(string: "\(baseURL)/api/exchange-rate") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: ExchangeRateResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                print("✅ Exchange rate: \(response.rate) JPY/USD")
                return response.rate
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("⚠️ Exchange rate fetch failed, using fallback: 155.0")
                return Just(155.0)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Calculate Portfolio Value
    func calculatePortfolioValue(stocks: [[String: Any]]) -> AnyPublisher<PortfolioValueResponse, Error> {
        print("📊 Calculating portfolio value")
        
        guard let url = URL(string: "\(baseURL)/api/portfolio/calculate") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        let body = ["stocks": stocks]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: PortfolioValueResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        priceCache.removeAll()
        print("🗑️ Cache cleared")
    }
}

// MARK: - Response Models

struct BackendStockPrice: Codable {
    let symbol: String
    let name: String?
    let price: Double
    let currency: String
    let market: String?
    let cached: Bool?
    let timestamp: String?
}

struct StockPrice {
    let symbol: String
    let name: String
    let price: Double
    let currency: String
    let market: String
    let cached: Bool
}

struct BatchStockResponse: Codable {
    let stocks: [BackendStockPrice]
    let timestamp: String?
}

struct ExchangeRateResponse: Codable {
    let from: String
    let to: String
    let rate: Double
    let source: String?
    let timestamp: String?
}

struct PortfolioValueResponse: Codable {
    let stocks: [[String: AnyCodable]]?
    let totalValueJPY: Double
    let exchangeRate: Double
    let timestamp: String?
}

// Helper for dynamic JSON
enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
}
