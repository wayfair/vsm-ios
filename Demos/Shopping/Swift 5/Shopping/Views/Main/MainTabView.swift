//
//  MainTabView.swift
//  Shopping
//

import SwiftUI

struct MainTabView: View {
    let viewDependencies: MainView.Dependencies

    init(dependencies: MainView.Dependencies, viewDependencies: MainView.Dependencies) {
        self.viewDependencies = viewDependencies
    }

    var body: some View {
        TabView {
            NavigationStack {
                ProductsView(dependencies: viewDependencies)
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
                Text("Products")
            }

            NavigationStack {
                AccountView(dependencies: viewDependencies)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Account")
            }
            .navigationViewStyle(.stack) // Fixes Layout Constraint errors

            CartTab(dependencies: viewDependencies, viewDependencies: viewDependencies)
        }
        .font(.headline)
    }
}
