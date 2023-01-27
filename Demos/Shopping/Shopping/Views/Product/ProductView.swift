//
//  ProductDetailView.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import SwiftUI
import VSM

struct ProductView: View {
    typealias Dependencies = ProductDetailLoaderModel.Dependencies & ProductDetailView.Dependencies & CartButtonView.Dependencies
    let dependencies: Dependencies
    let productId: Int
    @ViewState var state: ProductViewState
    
    init(dependencies: Dependencies, productId: Int) {
        self.dependencies = dependencies
        self.productId = productId
        let initializedModule = ProductDetailLoaderModel(
            dependencies: dependencies,
            productId: productId
        )
        _state = .init(wrappedValue: .initialized(initializedModule))
    }
    
    var body: some View {
        Group {
            switch state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let productDetail):
                ProductDetailView(dependencies: dependencies, productDetail: productDetail)
            case .error(message: let message, retry: let retryAction):
                loadingErrorView(message: message, retryAction: { $state.observe(retryAction()) })
                
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartButtonView(dependencies: dependencies)
            }
        }
        .onAppear {
            if case .initialized(let initializedModule) = state {
                $state.observe(initializedModule.loadProductDetail())
            }
        }
    }
    
    func addToCartButton<Style: ButtonStyle>(text: String, style: Style, action: (() -> Void)?) -> some View {
        Button(text) {
            action?()
        }
        .buttonStyle(style)
        .padding()
        .disabled(action == nil)
    }
    
    func loadingErrorView(message: String, retryAction: @escaping () -> Void) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(message)
            Button("Retry") {
                retryAction()
            }
        }
    }
}

// MARK: - Test Support

extension ProductView {
    init(state: ProductViewState, productId: Int = 0, dependencies: Dependencies = MockAppDependencies.noOp) {
        self.dependencies = dependencies
        self.productId = productId
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct ProductView_Previews: PreviewProvider {
    static var someProduct: ProductDetail { ProductDatabase.allProducts.first! }
    
    static var previews: some View {
        NavigationView {
            ProductView(state: .initialized(ProductDetailLoaderModel(dependencies: MockAppDependencies.noOp, productId: 0)))
        }
        .previewDisplayName("initialized State")
        
        NavigationView {
            ProductView(state: .loading)
        }
        .previewDisplayName("loading State")
        
        NavigationView {
            ProductView(state: .loaded(someProduct))
        }
        .previewDisplayName("loaded State")
        
        NavigationView {
            ProductView(state: .error(message: "Loading Error!", retry: { .empty() }))
        }
        .previewDisplayName("error State")
    }
}
