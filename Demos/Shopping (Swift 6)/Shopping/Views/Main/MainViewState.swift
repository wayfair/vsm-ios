//
//  MainViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum MainViewState {
    case initialized(DependenciesLoaderModel)
    case loading
    case loaded(MainViewLoadedModel)
}

// MARK: - Model Implementations
struct DependenciesLoaderModel {
    let dependenciesProvider: DependenciesProviding
    
    @StateSequenceBuilder
    func loadDependencies() -> StateSequence<MainViewState> {
        MainViewState.loading
        Next { await constructDependencies() }
    }
    
    func constructDependencies() async -> MainViewState {
        return .loaded(MainViewLoadedModel(dependencies: await dependenciesProvider.buildDependencies()))
    }
}

struct MainViewLoadedModel {
    let dependencies: MainView.Dependencies
    
    init(dependencies: MainView.Dependencies) {
        self.dependencies = dependencies
    }
}
