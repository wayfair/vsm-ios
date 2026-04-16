//
//  ProductsView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import VSM

enum ProductsNavDestination: Hashable {
    case product(id: Int)
}

struct ProductsView: View {
    typealias Dependencies = ProductsLoaderModel.Dependencies
                           & ProductView.Dependencies
                           & UIFrameworkDependency
    
    let dependencies: Dependencies
    
    @ViewState var state: ProductsViewState
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = ProductsLoaderModel(dependencies: dependencies)
        
        // Console logging enabled for this demo app. Logging is disabled by default.
        _state = .init(wrappedValue: .initialized(loaderModel), observedViewType: Self.self, loggingEnabled: true)
    }
    
    var body: some View {
        Group {
            switch state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let loadedModel):
                loadedView(loadedModel)
            case .error(let message, let retryAction):
                errorView(message: message, retryAction: {
                    $state.observe { await retryAction() }
                })
            }
        }
        .navigationTitle("Products")
        .onAppear {
            if case .initialized(let loaderModel) = state {
                $state.observe(loaderModel.loadProducts())
            }
        }
        .navigationDestination(for: ProductsNavDestination.self) { destination in
            switch destination {
            case .product(let productId):
                switch dependencies.frameworkProvider.framework {
                case .swiftUI:
                    ProductView(dependencies: dependencies, productId: productId)
                case .uiKit:
                    ProductUIKitView(dependencies: dependencies, productId: productId)
                }
            }
        }
    }
    
    @ViewBuilder
    func loadedView(_ loadedModel: ProductsLoadedModel) -> some View {
        if loadedModel.products.isEmpty {
            ZStack {
                Text("No products available.")
            }
        } else {
            let columns = Array(repeating: GridItem(.flexible()), count: 2)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns) {
                    ForEach(loadedModel.products, id: \.id) { product in
                        NavigationLink(value: ProductsNavDestination.product(id: product.id)) {
                            ProductGridItemView(product: product)
                        }
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
        ProductsView(dependencies: MockAppDependencies.noOp(), state: .loading)
    }
}
