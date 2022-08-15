//
//  CartButtonView.swift
//  Shopping
//
//  Created by Albert Bori on 2/17/22.
//

import SwiftUI
import VSM

struct CartButtonView: View, ViewStateRendering {
    typealias Dependencies = CartCountLoaderModel.Dependencies & CartView.Dependencies
    let dependencies: Dependencies
    @State var showCart: Bool = false
    @ObservedObject var container: StateContainer<CartButtonViewState>
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = CartCountLoaderModel(dependencies: dependencies)
        container = .init(state: .initialized(loaderModel))
        container.observe(loaderModel.loadCount())
    }
    
    var body: some View {
        Button(action: { showCart.toggle() }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: container.state.cartItemCount))
        .fullScreenCover(isPresented: $showCart) {
            CartView(dependencies: dependencies, showModal: $showCart)
        }
    }
}

// MARK: - Test Support

extension CartButtonView {
    init(dependencies: Dependencies, state: CartButtonViewState) {
        self.dependencies = dependencies
        container = .init(state: state)
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

struct CartButtonView_SingleStateViewModelExample: View, ViewStateRendering {
    typealias Dependencies = Alt_CartButtonViewState.Dependencies & CartView.Dependencies
    let dependencies: Dependencies
    @State var showCart: Bool = false
    @ObservedObject var container: StateContainer<Alt_CartButtonViewStateProviding>
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        container = .init(state: Alt_CartButtonViewState(dependencies: dependencies))
    }
    
    var body: some View {
        Button(action: { showCart.toggle() }) {
            Image(systemName: "cart")
        }
        .overlay(Badge(count: container.state.cartItemCount))
        .fullScreenCover(isPresented: $showCart) {
            CartView(dependencies: dependencies, showModal: $showCart)
        }
    }
}
