//
//  MainViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum MainViewState {
    case initialized(DependenciesLoaderModel)
    case loading
    case loaded(MainViewLoadedModel)
}

// MARK: - Model Implementations

struct DependenciesLoaderModel {
    let appDependenciesProvider: AsyncResource<MainView.Dependencies>
    
    func loadDependencies() -> AnyPublisher<MainViewState, Never> {
        let statePublisher = Just(MainViewState.loading)
        let loadedDependenciesPublisher = appDependenciesProvider.$state
            .compactMap({ loadingState -> MainViewState? in
                if case .loaded(let appDependencies) = loadingState {
                    return MainViewState.loaded(MainViewLoadedModel(dependencies: appDependencies))
                } else {
                    return nil
                }
            })        
        return statePublisher
            .merge(with: loadedDependenciesPublisher)
            .eraseToAnyPublisher()
    }
}

struct MainViewLoadedModel {
    let dependencies: MainView.Dependencies
}
