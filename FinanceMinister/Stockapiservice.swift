import Foundation
import Combine

// MARK: - Alpha Vantage Configuration
class AlphaVantageConfig {
    static let apiKey = "EGMGXJ92OF398TF6"
    static let baseURL = "https://www.alphavantage.co/query"
}

// MARK: - Alpha Vantage Models
struct AlphaVantageSearchResponse: Codable {
    let bestMatches: [AlphaVantageQuote]?
    
    enum CodingKeys: String, CodingKey {
        case bestMatches = "bestMatches"
    }
}

struct AlphaVantageQuote: Codable {
    let symbol: String
    let name: String
    let type: String?
    let region: String?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case currency = "8. currency"
    }
}

struct AlphaVantageGlobalQuote: Codable {
    let symbol: String?
    let price: String?
    let change: String?
    let changePercent: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

struct AlphaVantageGlobalQuoteResponse: Codable {
    let globalQuote: AlphaVantageGlobalQuote?
    
    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct AlphaVantageExchangeRate: Codable {
    let rate: String?
    let bidPrice: String?
    let askPrice: String?
    
    enum CodingKeys: String, CodingKey {
        case rate = "5. Exchange Rate"
        case bidPrice = "8. Bid Price"
        case askPrice = "9. Ask Price"
    }
}

struct AlphaVantageExchangeRateResponse: Codable {
    let exchangeRate: AlphaVantageExchangeRate?
    
    enum CodingKeys: String, CodingKey {
        case exchangeRate = "Realtime Currency Exchange Rate"
    }
}

// MARK: - Stock API Service (Alpha Vantage)
class StockAPIService {
    static let shared = StockAPIService()
    private let session = URLSession.shared
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300
    
    private init() {}
    
    // MARK: - Fetch Stock Price
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Double, Error> {
        if let cached = priceCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("✅ Using cached price for \(symbol): $\(cached.price)")
            return Just(cached.price)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        print("📊 Fetching real price for \(symbol) from Alpha Vantage")
        
        let urlString = "\(AlphaVantageConfig.baseURL)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(AlphaVantageConfig.apiKey)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("❌ HTTP Error \(status)")
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: AlphaVantageGlobalQuoteResponse.self, decoder: JSONDecoder())
            .tryMap { response -> Double in
                guard let globalQuote = response.globalQuote,
                      let priceStr = globalQuote.price,
                      let price = Double(priceStr) else {
                    print("❌ Could not extract price from Alpha Vantage response")
                    throw URLError(.badServerResponse)
                }
                
                self.priceCache[symbol] = (price: price, timestamp: Date())
                print("✅ Got price for \(symbol): $\(price)")
                return price
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("❌ Alpha Vantage API error: \(error.localizedDescription)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Search Stocks
    func searchStocks(query: String, market: MarketType) -> AnyPublisher<[Stock], Error> {
        print("🔍 Searching for '\(query)' in \(market == .japanese ? "Japanese" : "American") market")
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(AlphaVantageConfig.baseURL)?function=SYMBOL_SEARCH&keywords=\(encodedQuery)&apikey=\(AlphaVantageConfig.apiKey)") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("❌ Search HTTP Error \(status)")
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: AlphaVantageSearchResponse.self, decoder: JSONDecoder())
            .tryMap { response -> [Stock] in
                guard let matches = response.bestMatches, !matches.isEmpty else {
                    print("❌ No search results")
                    return []
                }
                
                var stocks: [Stock] = []
                
                for quote in matches {
                    // symbol is a String (not optional), so just check if it's not empty
                    guard !quote.symbol.isEmpty else {
                        continue
                    }
                    
                    let name = quote.name
                    let currency = quote.currency ?? (market == .american ? "USD" : "JPY")
                    
                    let stock = Stock(
                        id: quote.symbol,
                        symbol: quote.symbol,
                        name: name,
                        market: market,
                        currentPrice: 0,
                        currency: currency
                    )
                    stocks.append(stock)
                }
                
                print("✅ Found \(stocks.count) stocks for '\(query)'")
                return stocks
            }
            .catch { error -> AnyPublisher<[Stock], Error> in
                print("❌ Search error: \(error.localizedDescription)")
                return Just([])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch Exchange Rate
    func fetchExchangeRate() -> AnyPublisher<Double, Error> {
        print("💱 Fetching USD/JPY exchange rate from Alpha Vantage")
        
        let urlString = "\(AlphaVantageConfig.baseURL)?function=CURRENCY_EXCHANGE_RATE&from_currency=USD&to_currency=JPY&apikey=\(AlphaVantageConfig.apiKey)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: AlphaVantageExchangeRateResponse.self, decoder: JSONDecoder())
            .tryMap { response -> Double in
                guard let rate = response.exchangeRate,
                      let rateValue = Double(rate.rate ?? "") else {
                    print("❌ Could not extract exchange rate")
                    throw URLError(.badServerResponse)
                }
                
                print("✅ Got USD/JPY rate: \(rateValue)")
                return rateValue
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("⚠️ Exchange rate fetch failed: \(error.localizedDescription)")
                return Just(149.50)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Historical Data
    func fetchHistoricalData(symbol: String, market: MarketType) -> AnyPublisher<[PriceHistory], Error> {
        print("⚠️ Historical data not available in Alpha Vantage free tier")
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchExchangeRateHistory() -> AnyPublisher<[ExchangeRateHistory], Error> {
        print("⚠️ Exchange rate history not available in Alpha Vantage free tier")
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

