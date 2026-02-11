//
//  MainView.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import VSM

struct MainView: View {
    typealias Dependencies = ProductsView.Dependencies
                           & AccountView.Dependencies
                           & CartView.Dependencies
    
    @ViewState var state: MainViewState
    
    init(appDependenciesProvider: AsyncResource<MainView.Dependencies>) {
        let loaderModel = DependenciesLoaderModel(appDependenciesProvider: appDependenciesProvider)
        // Console logging enabled for this demo app. Logging is disabled by default.
        _state = .init(wrappedValue: .initialized(loaderModel), observedViewType: Self.self, loggingEnabled: true)
    }
    
    var body: some View {
        switch state {
        case .loading, .initialized:
            ProgressView()
                .onAppear {
                    if case .initialized(let loaderModel) = state {
                        $state.observe(loaderModel.loadDependencies())
                    }
                }
        case .loaded(let loadedModel):
            loadedView(loadedModel)
        }
    }
    
    func loadedView(_ loadedModel: MainViewLoadedModel) -> some View {
        MainTabView(dependencies: loadedModel.dependencies, viewDependencies: loadedModel.dependencies)
    }
}

// MARK: - Test Support

extension MainView {
    init(state: MainViewState) {
        _state = .init(wrappedValue: state)
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
