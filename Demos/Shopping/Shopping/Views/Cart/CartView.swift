//
//  CartView.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import SwiftUI
import VSM

struct CartView: View {
    typealias Dependencies = CartLoaderModel.Dependencies & CartLoadedModel.Dependencies & CartRemovingProductModel.Dependencies
    
    let dependencies: Dependencies

    @ViewState var state: CartViewState
    @State private var cartCountStore: CartCountStore
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: .initialized(CartLoaderModel(dependencies: dependencies)), loggingEnabled: true)
        _cartCountStore = .init(wrappedValue: CartCountStore(dependencies: dependencies))
    }
    
    var body: some View {
        ZStack {
            cartView(title: state.isOrderComplete ? "Receipt" : "Cart", cart: state.cart)
            switch state {
            case .initialized, .loading:
                ProgressView()
                    .accessibilityIdentifier("Loading Cart...")
            case .loadedEmpty:
                Text("Your cart is empty.")
            case .loaded:
                EmptyView()
            case .loadingError(let errorModel):
                loadingErrorView(errorModel)
            case .removingProduct, .checkingOut:
                progressOverlayView()
            case .removingProductError(message: let message, _), .checkoutError(let message, _):
                errorView(message: message)
            case .orderComplete:
                EmptyView()
            }
        }
        .onAppear {
            if case .initialized(let loaderModel) = state {
                $state.observe(loaderModel.loadCart())
            }
        }
        .onChange(of: cartCountStore.productCount) { oldValue, newValue in
            switch state {
            case .loaded(let model):
                $state.observe(model.reloadCart())
            case .loadedEmpty(let model):
                $state.observe(model.reloadCart())
            default:
                break
            }
        }
    }
    
    func loadingErrorView(_ errorModel: CartLoadingErrorModel) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(errorModel.message)
            Button("Retry") {
                $state.observe { await errorModel.retry() }
            }
            .buttonStyle(DemoButtonStyle())
        }
        .padding()
    }
    
    func progressOverlayView() -> some View {
        ZStack {
            Color.white.opacity(0.5).edgesIgnoringSafeArea(.all)
            ProgressView()
                .accessibilityIdentifier("Processing...")
        }
    }
    
    func cartView(title: String, cart: Cart) -> some View {
        VStack {
            HStack {
                Text(title).font(.largeTitle)
                Spacer()
                Text(cart.total, format: .currency(code: "USD"))
                    .font(.largeTitle)
                    .accessibilityLabel(Text("Total: \(cart.total.formatted(.currency(code: "USD")))"))
            }
            .padding()
            List(cart.products, id: \.cartId) { product in
                HStack {
                    Text(product.name)
                    Spacer()
                    Text(product.price, format: .currency(code: "USD"))
                }
                .frame(height: 44)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    switch state {
                    case .loaded(let loadedModel), .removingProductError(_, let loadedModel), .checkoutError(_, let loadedModel):
                        Button(role: .destructive) {
                            $state.observe { await loadedModel.removeProduct(id: product.cartId) }
                        } label : {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .accessibilityIdentifier("Remove \(product.name)")
                    default:
                        EmptyView()
                    }
                }
            }
            .refreshable {
                switch state {
                case .loaded(let loadedModel), .removingProductError(_, let loadedModel), .checkoutError(_, let loadedModel):
                    await $state.refresh(state: {
                        await loadedModel.refreshCart()
                    })
                case .loadedEmpty(let emptyModel):
                    await $state.refresh(state: {
                        await emptyModel.refreshCart()
                    })
                default:
                    break
                }
            }
            if case .orderComplete = state { } else {
                Spacer()
                Button(state.isCheckingOut ? "Placing Order..." : "Place Order") {
                    switch state {
                    case .loaded(let loadedModel), .removingProductError(_, let loadedModel), .checkoutError(_, let loadedModel):
                        $state.observe(loadedModel.checkout())
                    default:
                        break
                    }
                }
                .buttonStyle(DemoButtonStyle(enabled: state.canCheckout))
                .padding()
            }
        }
    }
    
    func errorView(message: String) -> some View {
        Text(message).font(.title)
            .padding()
            .background(Color.red.opacity(0.5))
            .cornerRadius(8)
    }
}

extension CartViewState {
    var allowModalDismissal: Bool {
        switch self {
        case .removingProduct, .checkingOut:
            return false
        default:
            return true
        }
    }
}

// MARK: - Test Support

extension CartView {
    init(state: CartViewState) {
        dependencies = MockAppDependencies.noOp
        _state = .init(wrappedValue: state)
        _cartCountStore = .init(wrappedValue: CartCountStore(dependencies: MockAppDependencies.noOp))
    }
}

// MARK: - Previews

struct CartView_Previews: PreviewProvider {
    static var previewCart: Cart {
        Cart(products: [
            .init(cartId: UUID(), productId: 1, name: "Product One", price: 199.99),
            .init(cartId: UUID(), productId: 2, name: "Product Two", price: 299.99)
        ])
    }
    
    static var previews: some View {
        CartView(state: .initialized(CartLoaderModel(dependencies: MockAppDependencies.noOp)))
            .previewDisplayName("initialized State")
        
        CartView(state: .loading)
            .previewDisplayName("loading State")
        
        CartView(state: .loadedEmpty(CartLoadedEmptyModel(dependencies: MockAppDependencies.noOp)))
            .previewDisplayName("loadedEmpty State")
        
        CartView(state: .loaded(
            CartLoadedModel(dependencies: MockAppDependencies.noOp, cart: previewCart)
        ))
        .previewDisplayName("loaded State")
        
        CartView(state: .loadingError(CartLoadingErrorModel(message: "Load Error!", retry: { .loadingError(.init(message: "Mock Error Message", retry: { .loadedEmpty(CartLoadedEmptyModel(dependencies: MockAppDependencies.noOp)) })) })))
            .previewDisplayName("loadingError State")
        
        CartView(state: .removingProduct(
            CartRemovingProductModel(dependencies: MockAppDependencies.noOp, cart: previewCart)
        ))
        .previewDisplayName("removingProduct State")
        
        CartView(state: .removingProductError(message: "Remove Error!",
                                              CartLoadedModel(dependencies: MockAppDependencies.noOp, cart: previewCart)))
            .previewDisplayName("removingProductError State")
        
        CartView(state: .checkingOut(CartCheckoutOutModel(cart: previewCart)))
        .previewDisplayName("checkingOut State")
        
        CartView(state: .checkoutError(message: "Checkout Error!",
                                       CartLoadedModel(dependencies: MockAppDependencies.noOp, cart: previewCart)))
            .previewDisplayName("checkoutError State")
        
        CartView(state: .orderComplete(CartOrderCompleteModel(cart: previewCart)))
        .previewDisplayName("orderComplete State")
    }
}
