//
//  FavoritesViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/18/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum FavoritesViewState {
    case initialized(FavoritesLoaderModeling)
    case loading
    case loaded(FavoritesViewLoadedModeling)
    case loadingError(FavoritesViewErrorModeling)
    case deleting([FavoritedProduct])
    case deletingError(FavoritesViewDeletingErrorModeling)
}

protocol FavoritesLoaderModeling {
    func loadFavorites() -> AnyPublisher<FavoritesViewState, Never>
}

protocol FavoritesViewLoadedModeling {
    var favorites: [FavoritedProduct] { get }
    func delete(productId: Int) -> AnyPublisher<FavoritesViewState, Never>
}

protocol FavoritesViewErrorModeling {
    var message: String { get }
    var retry: () -> AnyPublisher<FavoritesViewState, Never> { get }
}

protocol FavoritesViewDeletingErrorModeling {
    var favorites: [FavoritedProduct] { get }
    var message: String { get }
    var retry: () -> AnyPublisher<FavoritesViewState, Never> { get }
    var cancel: () -> AnyPublisher<FavoritesViewState, Never> { get }
}

protocol FavoritesViewModelBuilding {
    func buildLoaderModel() -> FavoritesLoaderModeling
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModeling
}

// MARK: - Model Implementations

struct FavoritesViewModelBuilder: FavoritesViewModelBuilding {
    typealias Dependencies = FavoritesLoaderModel.Dependencies & FavoritesViewLoadedModel.Dependencies
    let dependencies: Dependencies
    
    func buildLoaderModel() -> FavoritesLoaderModeling {
        return FavoritesLoaderModel(dependencies: dependencies, modelBuilder: self)
    }
    
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModeling {
        return FavoritesViewLoadedModel(dependencies: dependencies, modelBuilder: self, favorites: favorites)
    }
}

struct FavoritesLoaderModel: FavoritesLoaderModeling {
    typealias Dependencies = FavoritesRepositoryDependency
    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    
    func loadFavorites() -> AnyPublisher<FavoritesViewState, Never> {
        return dependencies.favoritesRepository.getFavoritesPublisher()
            .map({ (favoritesDatabaseState) -> FavoritesViewState in
                switch favoritesDatabaseState {
                case .loading:
                    return FavoritesViewState.loading
                case .loaded(let favorites):
                    return FavoritesViewState.loaded(modelBuilder.buildFavoritesViewLoadedModel(favorites: favorites))
                case .error(let error):
                    return FavoritesViewState.loadingError(
                        FavoritesViewErrorModel(
                            message: "Failed to load favorites: \(error)",
                            retry: { loadFavorites() }
                        )
                    )
                }
            }).eraseToAnyPublisher()
    }
}

struct FavoritesViewLoadedModel: FavoritesViewLoadedModeling {
    typealias Dependencies = FavoritesRepositoryDependency
    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    let favorites: [FavoritedProduct]
    
    func delete(productId: Int) -> AnyPublisher<FavoritesViewState, Never> {
        let statePublisher = Just(FavoritesViewState.deleting(favorites))
        let apiPublisher = dependencies.favoritesRepository.removeFavorite(productId: productId)
            .flatMap({ modelBuilder.buildLoaderModel().loadFavorites() })
            .catch({ error in Just(FavoritesViewState.deletingError(
                FavoritesViewDeletingErrorModel(
                    favorites: favorites,
                    message: "Failed to delete favorite: \(error)",
                    retry: { delete(productId: productId) },
                    cancel: { Just(FavoritesViewState.loaded(self)).eraseToAnyPublisher() })))
            })
        return statePublisher
                    .merge(with: apiPublisher)
                    .eraseToAnyPublisher()
    }
}

struct FavoritesViewErrorModel: FavoritesViewErrorModeling {
    let message: String
    let retry: () -> AnyPublisher<FavoritesViewState, Never>
}

struct FavoritesViewDeletingErrorModel: FavoritesViewDeletingErrorModeling {
    let favorites: [FavoritedProduct]
    let message: String
    let retry: () -> AnyPublisher<FavoritesViewState, Never>
    let cancel: () -> AnyPublisher<FavoritesViewState, Never>
}

extension FavoritesViewState {
    var favorites: [FavoritedProduct] {
        switch self {
        case .initialized, .loading, .loadingError:
            return []
        case .loaded(let model):
            return model.favorites
        case .deleting(let favorites):
            return favorites
        case .deletingError(let model):
            return model.favorites
        }
    }
}
