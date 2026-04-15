//
//  CartTab.swift
//  Shopping
//
//  Created by Bill Dunay on 2/4/26.
//
import SwiftUI

/// Wraps a NavigationStack in a Cart tab and applies the native `.badge()` modifier.
/// Isolates the observation of CartCountStore so that only this view redraws
/// when the cart count changes, leaving the parent TabView body stable.
struct CartTab: View {
    typealias Dependencies = CartRepositoryDependency

    let viewDependencies: MainView.Dependencies
    @State private var cartCountStore: CartCountStore

    init(dependencies: Dependencies, viewDependencies: MainView.Dependencies) {
        self.viewDependencies = viewDependencies
        _cartCountStore = .init(wrappedValue: CartCountStore(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            CartView(dependencies: viewDependencies)
        }
        .tabItem {
            Label("Cart", systemImage: "cart")
        }
        .badge(cartCountStore.productCount)
    }
}
