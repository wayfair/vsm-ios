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
    case initialized(DependenciesLoaderModeling)
    case loading
    case loaded(MainViewLoadedModeling)
}

protocol DependenciesLoaderModeling {
    func loadDependencies() -> AnyPublisher<MainViewState, Never>
}

protocol MainViewLoadedModeling {
    var dependencies: MainView.Dependencies { get }
}

// MARK: - Model Implementations

struct DependenciesLoaderModel: DependenciesLoaderModeling {
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

struct MainViewLoadedModel: MainViewLoadedModeling {
    let dependencies: MainView.Dependencies
}
