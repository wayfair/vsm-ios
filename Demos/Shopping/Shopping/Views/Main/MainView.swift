//
//  MainView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import VSM

struct MainView: View, ViewStateRendering {
    typealias Dependencies = ProductsView.Dependencies & AccountView.Dependencies
    @ObservedObject private(set) var container: StateContainer<MainViewState>
    
    init(appDependenciesProvider: AsyncResource<MainView.Dependencies>) {
        //_StateContainerDebugLogger._enableAll = true // Enable this debug-only flag to view all state changes in all `StateContainer`s
        let loaderModel = DependenciesLoaderModel(appDependenciesProvider: appDependenciesProvider)
        container = .init(state: .initialized(loaderModel))
        container.observe(loaderModel.loadDependencies())
    }
    
    var body: some View {
        switch state {
        case .loading, .initialized:
            ProgressView()
        case .loaded(let loadedModel):
            loadedView(loadedModel)
        }
    }
    
    func loadedView(_ loadedModel: MainViewLoadedModeling) -> some View {
        TabView {
            NavigationView {
                ProductsView(dependencies: loadedModel.dependencies)
            }
            .tabItem {
                Image(systemName: "square.grid.2x2")
                Text("Products")
            }
            .navigationViewStyle(.stack) // Fixes Layout Constraint errors
            
            NavigationView {
                AccountView(dependencies: loadedModel.dependencies)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Account")
            }
            .navigationViewStyle(.stack) // Fixes Layout Constraint errors
        }.font(.headline)
    }
}

// MARK: - Test Support

extension MainView {
    init(state: MainViewState) {
        container = .init(state: state)
    }
}

// MARK: - Previews

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(state: .loading)
            .previewDisplayName("loading State")
        
        MainView(state: .loaded(MainViewLoadedModel(dependencies: MockAppDependencies.noOp)))
            .previewDisplayName("loaded State")
    }
}
