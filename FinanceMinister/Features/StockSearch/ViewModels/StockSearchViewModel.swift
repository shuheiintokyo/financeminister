import Foundation
import Combine

class StockSearchViewModel: ObservableObject {
    @Published var searchResults: [Stock] = []
    @Published var isSearching = false
    
    private var cancellables = Set<AnyCancellable>()
    private let stockAPIService = StockAPIService.shared
    
    func searchStocks(query: String, market: MarketType) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        stockAPIService.searchStocks(query: query, market: market)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSearching = false
                if case .failure(let error) = completion {
                    print("❌ Search error: \(error)")
                }
            } receiveValue: { [weak self] stocks in
                self?.searchResults = stocks
                print("✅ Found \(stocks.count) results")
            }
            .store(in: &cancellables)
    }
}
