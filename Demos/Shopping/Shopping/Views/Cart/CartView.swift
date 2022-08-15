//
//  CartView.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import SwiftUI
import VSM

struct CartView: View, ViewStateRendering {
    typealias Dependencies = CartLoaderModel.Dependencies & CartLoadedModel.Dependencies & CartRemovingProductModel.Dependencies
    let dependencies: Dependencies
    @Binding var showModal: Bool
    @StateObject var container: StateContainer<CartViewState>
    
    init(dependencies: Dependencies, showModal: Binding<Bool>) {
        self.dependencies = dependencies
        self._showModal = showModal
        _container = .init(state: .initialized(CartLoaderModel(dependencies: dependencies)))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                cartView(title: container.state.isOrderComplete ? "Reciept" : "Cart", cart: container.state.cart)
                switch container.state {
                case .initialized, .loading:
                    ProgressView()
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
            .navigationBarItems(trailing: dismissButtonView())
        }
        .onAppear {
            if case .initialized(let loaderModel) = container.state {
                container.observe(loaderModel.loadCart())
            }
        }
    }
    
    func loadingErrorView(_ errorModel: CartLoadingErrorModeling) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(errorModel.message)
            Button("Retry") {
                container.observe(errorModel.retry())
            }
            .buttonStyle(DemoButtonStyle())
        }
        .padding()
    }
    
    func progressOverlayView() -> some View {
        ZStack {
            Color.white.opacity(0.5).edgesIgnoringSafeArea(.all)
            ProgressView()
        }
    }
    
    func cartView(title: String, cart: Cart) -> some View {
        VStack {
            HStack {
                Text(title).font(.largeTitle)
                Spacer()
                Text(cart.total, format: .currency(code: "USD")).font(.largeTitle)
            }.padding()
            List(cart.products, id: \.cartId) { product in
                HStack {
                    Text(product.name)
                    Spacer()
                    Text(product.price, format: .currency(code: "USD"))
                }
                .frame(height: 44)
                .swipeActions {
                    switch container.state {
                    case .loaded(let loadedModel), .removingProductError(_, let loadedModel), .checkoutError(_, let loadedModel):
                        Button(role: .destructive) {
                            container.observe(loadedModel.removeProduct(id: product.cartId))
                        } label : {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            if case .orderComplete = container.state { } else {
                Spacer()
                Button(container.state.isCheckingOut ? "Placing Order..." : "Place Order") {
                    switch container.state {
                    case .loaded(let loadedModel), .removingProductError(_, let loadedModel), .checkoutError(_, let loadedModel):
                        container.observe(loadedModel.checkout())
                    default:
                        break
                    }
                }
                .buttonStyle(DemoButtonStyle(enabled: container.state.canCheckout))
                .padding()
            }
        }
    }
    
    func dismissButtonView() -> some View {
        Button(action: {
            if container.state.allowModalDismissal {
                self.showModal = false
            }
        }) {
            if container.state.allowModalDismissal {
                Image(systemName: "xmark")
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
        _showModal = .init(get: { true }, set: { _ in })
        _container = .init(state: state)
    }
}

// MARK: - Previews

struct CartView_Previews: PreviewProvider {
    static var previewCart: Cart {
        Cart(products: [
            .init(cartId: 1, productId: 1, name: "Product One", price: 199.99),
            .init(cartId: 2, productId: 2, name: "Product Two", price: 299.99)
        ])
    }
    
    static var previews: some View {
        CartView(state: .initialized(CartLoaderModel(dependencies: MockAppDependencies.noOp)))
            .previewDisplayName("initialized State")
        
        CartView(state: .loading)
            .previewDisplayName("loading State")
        
        CartView(state: .loadedEmpty)
            .previewDisplayName("loadedEmpty State")
        
        CartView(state: .loaded(
            CartLoadedModel(dependencies: MockAppDependencies.noOp, cart: previewCart)
        ))
        .previewDisplayName("loaded State")
        
        CartView(state: .loadingError(CartLoadingErrorModel(message: "Load Error!", retry: { .empty() })))
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
