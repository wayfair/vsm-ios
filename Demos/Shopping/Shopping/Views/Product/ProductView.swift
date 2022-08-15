//
//  ProductDetailView.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import SwiftUI
import VSM

struct ProductView: View, ViewStateRendering {
    typealias Dependencies = ProductDetailLoaderModel.Dependencies & ProductDetailView.Dependencies & CartButtonView.Dependencies
    let dependencies: Dependencies
    let productId: Int
    @ObservedObject var container: StateContainer<ProductViewState>
    
    init(dependencies: Dependencies, productId: Int) {
        self.dependencies = dependencies
        self.productId = productId
        let initializedModule = ProductDetailLoaderModel(
            dependencies: dependencies,
            productId: productId
        )
        container = .init(state: .initialized(initializedModule))
        container.observe(initializedModule.loadProductDetail())
    }
    
    var body: some View {
        Group {
            switch container.state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let productDetail):
                ProductDetailView(dependencies: dependencies, productDetail: productDetail)
            case .error(message: let message, retry: let retryAction):
                loadingErrorView(message: message, retryAction: { container.observe(retryAction()) })
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartButtonView(dependencies: dependencies)
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
        container = .init(state: state)
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
