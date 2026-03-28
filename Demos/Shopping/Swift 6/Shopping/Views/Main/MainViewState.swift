//
//  MainViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum MainViewState: Sendable {
    case initialized(DependenciesLoaderModel)
    case loading
    case loaded(MainViewLoadedModel)
}

// MARK: - Model Implementations

struct DependenciesLoaderModel: Sendable {
    let dependenciesProvider: DependenciesProviding
    
    @StateSequenceBuilder
    func loadDependencies() -> StateSequence<MainViewState> {
        MainViewState.loading
        Next { await constructDependencies() }
    }
    
    @MainActor
    func constructDependencies() async -> MainViewState {
        return .loaded(MainViewLoadedModel(dependencies: await dependenciesProvider.buildDependencies()))
    }
}

struct MainViewLoadedModel {
    let dependencies: MainView.Dependencies
    let cardCount: Int
    
    init(dependencies: MainView.Dependencies, cardCount: Int = 0) {
        self.dependencies = dependencies
        self.cardCount = cardCount
    }
    
    func observeCardCount() -> AsyncStream<MainViewState> {
        AsyncStream { continuation in
            Task {
                let cardCountStream = await dependencies.cartRepository.cartCountStream().1
                for await cardCount in cardCountStream {
                    continuation.yield(.loaded(.init(dependencies: dependencies, cardCount: cardCount)))
                }
            }
        }
    }
}
