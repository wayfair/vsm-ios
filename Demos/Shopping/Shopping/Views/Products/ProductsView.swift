//
//  ProductsView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import VSM

struct ProductsView: View {
    typealias Dependencies = ProductsLoaderModel.Dependencies & ProductGridItemView.Dependencies & CartButtonView.Dependencies
    let dependencies: Dependencies
    @ViewState var state: ProductsViewState
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = ProductsLoaderModel(dependencies: dependencies)
        _state = .init(wrappedValue: .initialized(loaderModel))
        $state.observe(loaderModel.loadProducts())
    }
    
    var body: some View {
        Group {
            switch state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let loadedModel):
                loadedView(loadedModel)
            case .error(let message, let retryAction):
                errorView(message: message, retryAction: { $state.observe(retryAction()) })
            }
        }
        .navigationTitle("Products")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartButtonView(dependencies: dependencies)
            }
        }
    }
    
    @ViewBuilder
    func loadedView(_ loadedModel: ProductsLoadedModeling) -> some View {
        if loadedModel.products.isEmpty {
            ZStack {
                Text("No products available.")
            }
        } else {
            let columns = Array(repeating: GridItem(.flexible()), count: 2)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns) {
                    ForEach(loadedModel.products, id: \.id) { product in
                        ProductGridItemView(dependencies: dependencies, product: product)
                    }
                }
            }
        }
    }
    
    func errorView(message: String, retryAction: @escaping () -> Void) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(message)
            Button("Retry") {
                retryAction()
            }
        }
    }
}

// MARK: - Previews & Test Support

extension ProductsView {
    init(dependencies: Dependencies, state: ProductsViewState) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct ProductsView_Previews: PreviewProvider {
    static var previews: some View {
        ProductsView(dependencies: MockAppDependencies.noOp, state: .loading)
    }
}
