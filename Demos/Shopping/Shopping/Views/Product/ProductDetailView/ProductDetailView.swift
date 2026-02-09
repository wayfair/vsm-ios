//
//  ProductDetailView.swift
//  Shopping
//
//  Created by Albert Bori on 2/22/22.
//

import SwiftUI
import VSM

struct ProductDetailView: View {
    typealias Dependencies = AddToCartModel.Dependencies
                           & FavoriteButtonView.Dependencies
    
    let dependencies: Dependencies
    let productDetail: ProductDetail
    
    @ViewState var state: ProductDetailViewState
    
    init(dependencies: Dependencies, productDetail: ProductDetail) {
        self.dependencies = dependencies
        self.productDetail = productDetail
        // Console logging enabled for this demo app. Logging is disabled by default.
        _state = .init(wrappedValue: .viewing(AddToCartModel(dependencies: dependencies, productId: productDetail.id)), loggingEnabled: true)
    }
    
    var body: some View {
        ZStack {
            VStack {
                productDetailsView()
                Spacer()
                addToCartButtonView()
            }
            .navigationTitle(productDetail.name)
            
            VStack {
                addToCartToastView()
                    .opacity(state.isAddedToCart ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: state.isAddedToCart)
                addToCartErrorView(message: state.addToCartErrorMessage ?? "")
                    .opacity(state.isAddToCartError ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: state.isAddToCartError)
            }
            .allowsHitTesting(false)
        }
    }
    
    func productDetailsView() -> some View {
        VStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline) {
                Text(productDetail.price, format: .currency(code: "USD"))
                Spacer()
                FavoriteButtonView(dependencies: dependencies, productId: productDetail.id, productName: productDetail.name)
            }
            .padding()
            
            AsyncImage(url: productDetail.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .accessibilityIdentifier("\(productDetail.name) Image")
            
            Text(productDetail.description).font(.body)
                .padding()
        }
    }
    
    func addToCartButtonView() -> some View {
        Button(state.isAddingToCart ? "Adding to Cart..." : "Add to Cart") {
            switch state {
            case .viewing(let addToCartModel), .addedToCart(let addToCartModel), .addToCartError(_, let addToCartModel):
                $state.observe(addToCartModel.addToCart())
            case .addingToCart:
                break
            }
        }
        .buttonStyle(DemoButtonStyle(enabled: state.canAddToCart))
        .padding()
        .disabled(!state.canAddToCart)
    }
    
    func addToCartToastView() -> some View {
        Text("✅ Added \(productDetail.name) to cart.")
            .padding()
            .background(Color.white.opacity(0.75))
            .cornerRadius(8)
    }
    
    func addToCartErrorView(message: String) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(message)
                .padding()
            Text("Please try again.")
        }
        .padding()
        .background(Color.red.opacity(0.5))
        .cornerRadius(8)
    }
}

//MARK: - Test Support

extension ProductDetailView {
    init(productDetail: ProductDetail, state: ProductDetailViewState, dependencies: Dependencies = MockAppDependencies.noOp) {
        self.dependencies = dependencies
        self.productDetail = productDetail
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct ProductDetailView_Previews: PreviewProvider {
    static var someProduct: ProductDetail { ProductDatabase.allProducts.first! }
    
    static var previews: some View {
        
        ProductDetailView(productDetail: someProduct, state: .viewing(AddToCartModel(dependencies: MockAppDependencies.noOp, productId: 1)))
            .previewDisplayName("viewing State")
        
        ProductDetailView(productDetail: someProduct, state: .addingToCart)
            .previewDisplayName("addingToCart State")
        
        ProductDetailView(productDetail: someProduct, state: .addedToCart(AddToCartModel(dependencies: MockAppDependencies.noOp, productId: 1)))
            .previewDisplayName("addedToCart State")
        
        ProductDetailView(productDetail: someProduct, state: .addToCartError(message: "Add to Cart Error!",
                                                                             AddToCartModel(dependencies: MockAppDependencies.noOp, productId: 1)))
            .previewDisplayName("addedToCart State")
    }
}
