import SwiftUI
import Combine

// MARK: - Add Holding View
struct AddHoldingView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedStock: Stock?
    @State private var searchText: String = ""
    @State private var searchResults: [Stock] = []
    @State private var quantity: String = ""
    @State private var isSearching: Bool = false
    @State private var showClearButton: Bool = false
    
    var canAddHolding: Bool {
        selectedStock != nil && !quantity.isEmpty && Double(quantity) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Stock Selection Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("銘柄を選択")
                        .font(.headline)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("銘柄名またはシンボル", text: $searchText)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: searchText) { newValue in
                                showClearButton = !newValue.isEmpty
                                if newValue.count >= 1 {
                                    searchStocks(query: newValue)
                                } else {
                                    searchResults = []
                                }
                            }
                        
                        if showClearButton {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                selectedStock = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Selected Stock Display
                    if let stock = selectedStock {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stock.name)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    Text(stock.symbol)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(action: {
                                    selectedStock = nil
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text("現在価格: \(stock.currentPrice) \(stock.currency)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Search Results
                    if !searchResults.isEmpty && selectedStock == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("検索結果")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(searchResults, id: \.id) { stock in
                                        Button(action: {
                                            selectedStock = stock
                                            searchResults = []
                                            searchText = ""
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(stock.name)
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.black)
                                                    Text(stock.symbol)
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                }
                .padding()
                
                // Input Section
                VStack(alignment: .leading, spacing: 16) {
                    // Quantity Input
                    VStack(alignment: .leading) {
                        Text("数量")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        TextField("数量を入力", text: $quantity)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                // Add Button
                Button(action: addHolding) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("銘柄を追加")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canAddHolding ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.headline)
                }
                .disabled(!canAddHolding)
                .padding()
                
                Spacer()
            }
            .navigationTitle("株を追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
    }
    
    // MARK: - Methods
    private func searchStocks(query: String) {
        isSearching = true
        
        // Determine market based on search query
        let market: MarketType = query.isEmpty ? .american :
                                 query.contains("株") ||
                                 query.contains("銘") ||
                                 query.allSatisfy({ $0.isLetter && $0.asciiValue ?? 0 > 127 }) ? .japanese : .american
        
        StockAPIService.shared.searchStocks(query: query, market: market)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isSearching = false
                if case .failure(let error) = completion {
                    print("❌ Search error: \(error)")
                }
            } receiveValue: { stocks in
                self.searchResults = stocks
                print("✅ Found \(stocks.count) results")
            }
            .store(in: &viewModel.cancellables)
    }
    
    private func addHolding() {
        guard let stock = selectedStock,
              let qty = Double(quantity),
              qty > 0 else {
            print("❌ Invalid input")
            return
        }
        
        print("DEBUG: addHolding called")
        print("DEBUG: selectedStock = \(stock.name)")
        print("DEBUG: quantity = '\(quantity)'")
        print("DEBUG: canAddHolding = \(canAddHolding)")
        
        // Create PortfolioHolding object
        let holding = PortfolioHolding(
            stock: stock,
            quantity: qty,
            purchasePrice: 0,
            purchaseDate: Date(),
            account: "Default"
        )
        
        // Add holding to view model
        viewModel.addHolding(holding)
        
        print("✅ Holding added successfully")
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
#if DEBUG
struct AddHoldingView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PortfolioViewModel()
        AddHoldingView(viewModel: viewModel)
    }
}
#endif
