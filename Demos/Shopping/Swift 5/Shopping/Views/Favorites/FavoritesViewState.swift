//
//  FavoritesViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/18/22.
//

import Combine
import Foundation
import VSM

// MARK: - State & Model Definitions

enum FavoritesViewState: Equatable {
    case initialized(FavoritesLoaderModel)
    case loading
    case loaded(FavoritesViewLoadedModel)
    case loadingError(FavoritesViewErrorModel)
    case deleting([FavoritedProduct])
    case deletingError(FavoritesViewDeletingErrorModel)
}

protocol FavoritesViewModelBuilding {
    func buildLoaderModel() -> FavoritesLoaderModel
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModel
}

// MARK: - Model Implementations

struct FavoritesViewModelBuilder: FavoritesViewModelBuilding {
    typealias Dependencies = FavoritesLoaderModel.Dependencies & FavoritesViewLoadedModel.Dependencies
    let dependencies: Dependencies
    
    func buildLoaderModel() -> FavoritesLoaderModel {
        return FavoritesLoaderModel(dependencies: dependencies, modelBuilder: self)
    }
    
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModel {
        return FavoritesViewLoadedModel(dependencies: dependencies, modelBuilder: self, favorites: favorites)
    }
}

struct FavoritesLoaderModel: Equatable {
    typealias Dependencies = FavoritesRepositoryDependency

    static func == (lhs: FavoritesLoaderModel, rhs: FavoritesLoaderModel) -> Bool {
        // This is just to help with automatic conformance with Equatable on FavoritesViewState
        // Normally you would be more thorough
        true
    }
    
    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    
    @StateSequenceBuilder
    func loadFavorites() -> StateSequence<FavoritesViewState> {
        FavoritesViewState.loading
        Next { await fetchFavorites() }
    }
    
    @concurrent
    private func fetchFavorites() async -> FavoritesViewState {
        do {
            let favorites = try await dependencies.favoritesRepository.getFavoritesPublisher().asyncFirstLoaded()
            return .loaded(modelBuilder.buildFavoritesViewLoadedModel(favorites: favorites))
        } catch {
            return .loadingError(
                FavoritesViewErrorModel(
                    message: "Failed to load favorites: \(error)",
                    retry: { await fetchFavorites() }
                )
            )
        }
    }
}

struct FavoritesViewLoadedModel: Equatable {
    typealias Dependencies = FavoritesRepositoryDependency

    static func == (lhs: FavoritesViewLoadedModel, rhs: FavoritesViewLoadedModel) -> Bool {
        lhs.favorites == rhs.favorites
    }
    
    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    let favorites: [FavoritedProduct]
    
    @StateSequenceBuilder
    func delete(productId: Int) -> StateSequence<FavoritesViewState> {
        FavoritesViewState.deleting(favorites.filter({ $0.id != productId }))
        Next { await performDelete(productId: productId) }
    }
    
    @concurrent
    private func performDelete(productId: Int) async -> FavoritesViewState {
        do {
            try await dependencies.favoritesRepository.removeFavorite(productId: productId).asyncAwait()
            let favorites = try await dependencies.favoritesRepository.getFavoritesPublisher().asyncFirstLoaded()
            return .loaded(modelBuilder.buildFavoritesViewLoadedModel(favorites: favorites))
        } catch {
            return .deletingError(
                FavoritesViewDeletingErrorModel(
                    favorites: favorites,
                    message: "Failed to delete favorite: \(error)",
                    retry: { await performDelete(productId: productId) },
                    cancel: { .loaded(self) }
                )
            )
        }
    }
}

struct FavoritesViewErrorModel: Equatable {
    static func == (lhs: FavoritesViewErrorModel, rhs: FavoritesViewErrorModel) -> Bool {
        lhs.message == rhs.message
    }
    
    let message: String
    let retry: () async -> FavoritesViewState
}

struct FavoritesViewDeletingErrorModel: Equatable {
    static func == (lhs: FavoritesViewDeletingErrorModel, rhs: FavoritesViewDeletingErrorModel) -> Bool {
        lhs.message == rhs.message && lhs.favorites == rhs.favorites
    }
    
    let favorites: [FavoritedProduct]
    let message: String
    let retry: () async -> FavoritesViewState
    let cancel: () -> FavoritesViewState
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
