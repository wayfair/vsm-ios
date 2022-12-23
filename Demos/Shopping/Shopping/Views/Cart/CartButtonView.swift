//
//  CartButtonView.swift
//  Shopping
//
//  Created by Albert Bori on 2/17/22.
//

import SwiftUI
import VSM

struct CartButtonView: View {
    typealias Dependencies = CartCountLoaderModel.Dependencies & CartView.Dependencies
    let dependencies: Dependencies
    @State var showCart: Bool = false
    @ViewState var state: CartButtonViewState
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = CartCountLoaderModel(dependencies: dependencies)
        _state = .init(wrappedValue: .initialized(loaderModel))
        $state.observe(loaderModel.loadCount())
    }
    
    var body: some View {
        Button(action: { showCart.toggle() }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: state.cartItemCount))
        .fullScreenCover(isPresented: $showCart) {
            CartView(dependencies: dependencies, showModal: $showCart)
        }
    }
}

// MARK: - Test Support

extension CartButtonView {
    init(dependencies: Dependencies, state: CartButtonViewState) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct CartButtonView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack { }
            .toolbar {
                CartButtonView(dependencies: MockAppDependencies.noOp, state: .loaded(cartItemCount: 0))
            }
        }
        .previewDisplayName("0 Count State")
        
        NavigationView {
            VStack { }
            .toolbar {
                CartButtonView(dependencies: MockAppDependencies.noOp, state: .loaded(cartItemCount: 1))
            }
        }
        .previewDisplayName("1 Count State")
        
        NavigationView {
            VStack { }
            .toolbar {
                CartButtonView(dependencies: MockAppDependencies.noOp, state: .loaded(cartItemCount: 99))
            }
        }
        .previewDisplayName("99 Count State")
    }
}

// MARK: - Alternative approach using a simple single-state view model:

struct CartButtonView_SingleStateViewModelExample: View {
    typealias Dependencies = Alt_CartButtonViewState.Dependencies & CartView.Dependencies
    let dependencies: Dependencies
    @State var showCart: Bool = false
    @ViewState var state: Alt_CartButtonViewStateProviding
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: Alt_CartButtonViewState(dependencies: dependencies))
    }
    
    var body: some View {
        Button(action: { showCart.toggle() }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: state.cartItemCount))
        .fullScreenCover(isPresented: $showCart) {
            CartView(dependencies: dependencies, showModal: $showCart)
        }
    }
}
