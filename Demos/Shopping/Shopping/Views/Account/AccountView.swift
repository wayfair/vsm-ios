//
//  AccountView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI

struct AccountView: View {
    typealias Dependencies = FavoritesView.Dependencies & CartButtonView.Dependencies & SettingsView.Dependencies
    let dependencies: Dependencies
    
    var body: some View {
        List {
            NavigationLink("Favorites", destination: FavoritesView(dependencies: dependencies))
            NavigationLink("Settings", destination: SettingsView(dependencies: dependencies))
        }
        .listStyle(.grouped)
        .navigationTitle("Account")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartButtonView(dependencies: dependencies)
            }
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountView(dependencies: MockAppDependencies.noOp)
        }
        .previewDisplayName("Default State")
    }
}
