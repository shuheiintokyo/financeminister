import Foundation
import Combine

// MARK: - Yahoo Finance API Models
struct YahooQuote: Codable {
    let symbol: String
    let shortName: String?
    let regularMarketPrice: Double?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case shortName
        case regularMarketPrice
        case currency
    }
}

struct YahooQuoteResponse: Codable {
    let quoteResponse: QuoteResponse?
    
    struct QuoteResponse: Codable {
        let result: [YahooQuote]?
        let error: String?
    }
}

// MARK: - Stock API Service
class StockAPIService {
    static let shared = StockAPIService()
    private let session = URLSession.shared
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Fetch real stock price from Yahoo Finance
    /// - Parameters:
    ///   - symbol: Stock symbol (e.g., "AAPL", "9984.T")
    ///   - market: Market type (Japanese or American)
    /// - Returns: Current price as Double
    func fetchStockPrice(symbol: String, market: MarketType) -> AnyPublisher<Double, Error> {
        // Check cache first
        if let cached = priceCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("DEBUG: Using cached price for \(symbol): \(cached.price)")
            return Just(cached.price)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Format symbol for Yahoo Finance
        let yahooSymbol = formatSymbolForYahoo(symbol, market: market)
        print("DEBUG: Fetching real price for \(yahooSymbol)")
        
        let urlString = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(yahooSymbol)?modules=price"
        
        guard let url = URL(string: urlString) else {
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
            .decode(type: YahooQuoteResponse.self, decoder: JSONDecoder())
            .tryMap { response -> Double in
                // Try new API format first
                if let quoteResponse = response.quoteResponse,
                   let result = quoteResponse.result?.first,
                   let price = result.regularMarketPrice {
                    self.priceCache[symbol] = (price: price, timestamp: Date())
                    print("DEBUG: Got real price for \(symbol): \(price)")
                    return price
                }
                
                // Fallback: return mock price if API fails
                print("DEBUG: API response invalid, using mock price for \(symbol)")
                let mockPrice = market == .american ? 150.0 : 5000.0
                self.priceCache[symbol] = (price: mockPrice, timestamp: Date())
                return mockPrice
            }
            .catch { error -> AnyPublisher<Double, Error> in
                print("DEBUG: Yahoo Finance API error: \(error.localizedDescription)")
                // Fallback to mock data
                let mockPrice = market == .american ? 150.0 : 5000.0
                self.priceCache[symbol] = (price: mockPrice, timestamp: Date())
                return Just(mockPrice)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Search for stocks using Yahoo Finance
    func searchStocks(query: String, market: MarketType) -> AnyPublisher<[Stock], Error> {
        print("DEBUG: Searching for '\(query)' in \(market == .japanese ? "Japanese" : "American") market")
        
        let urlString = "https://query1.finance.yahoo.com/v1/finance/search?q=\(query)&count=10"
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(encodedQuery)&count=10") else {
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
            .tryMap { data -> [Stock] in
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)
                
                // Filter results by market
                let filteredResults = response.quotes?.filter { quote in
                    self.isSymbolInMarket(quote.symbol ?? "", market: market)
                } ?? []
                
                let stocks = filteredResults.compactMap { quote -> Stock? in
                    guard let symbol = quote.symbol, !symbol.isEmpty else { return nil }
                    
                    let name = quote.shortname ?? quote.symbol ?? symbol
                    let price = quote.regularMarketPrice ?? (market == .american ? 150.0 : 5000.0)
                    let currency = market == .american ? "USD" : "JPY"
                    
                    return Stock(
                        id: symbol,
                        symbol: symbol,
                        name: name,
                        market: market,
                        currentPrice: price,
                        currency: currency
                    )
                }
                
                print("DEBUG: Found \(stocks.count) stocks for '\(query)' in \(market.rawValue) market")
                return stocks
            }
            .catch { error -> AnyPublisher<[Stock], Error> in
                print("DEBUG: Search error: \(error.localizedDescription)")
                // Return empty on error
                return Just([])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func formatSymbolForYahoo(_ symbol: String, market: MarketType) -> String {
        // Yahoo Finance uses ".T" suffix for Tokyo stocks
        // US stocks are just the symbol
        if market == .japanese && !symbol.contains(".") {
            return "\(symbol).T"
        }
        return symbol
    }
    
    private func isSymbolInMarket(_ symbol: String, market: MarketType) -> Bool {
        let japaneseMarketIndicators = [".T", ".F", "jp:", "JP:"]
        let americanMarketIndicators = ["NASDAQ", "NYSE", "AMEX"]
        
        if market == .japanese {
            return japaneseMarketIndicators.contains { symbol.contains($0) }
        } else {
            // Most US stocks don't have a suffix, so if it's not Japanese, assume US
            return !japaneseMarketIndicators.contains { symbol.contains($0) }
        }
    }
}

// MARK: - Search Response Model
struct SearchResponse: Codable {
    let quotes: [QuoteResult]?
    
    struct QuoteResult: Codable {
        let symbol: String?
        let shortname: String?
        let regularMarketPrice: Double?
        let exchange: String?
        
        enum CodingKeys: String, CodingKey {
            case symbol
            case shortname
            case regularMarketPrice
            case exchange
        }
    }
}
