//
//  AccountView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI

enum AccountNavDestination: Hashable {
    case profile, favorites, settings
}

struct AccountView: View {
    typealias Dependencies = ProfileView.Dependencies
                           & FavoritesView.Dependencies
                           & SettingsView.Dependencies
    
    let dependencies: Dependencies
    
    var body: some View {
        List {
            NavigationLink(value: AccountNavDestination.profile) {
                Text("Profile")
            }
            NavigationLink(value: AccountNavDestination.favorites) {
                Text("Favorites")
            }
            NavigationLink(value: AccountNavDestination.settings) {
                Text("Settings")
            }
        }
        .listStyle(.grouped)
        .navigationTitle("Account")
        .navigationDestination(for: AccountNavDestination.self) { destination in
            switch destination {
            case .profile:
                ProfileView(dependencies: dependencies)
            case .favorites:
                FavoritesView(dependencies: dependencies)
            case .settings:
                SettingsView(dependencies: dependencies)
            }
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountView(dependencies: MockAppDependencies.noOp())
        }
        .previewDisplayName("Default State")
    }
}
