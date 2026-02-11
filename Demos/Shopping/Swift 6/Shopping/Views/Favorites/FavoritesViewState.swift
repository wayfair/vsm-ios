//
//  FavoritesViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/18/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum FavoritesViewState: Equatable, Sendable {
    case initialized(FavoritesLoaderModel)
    case loading
    case loaded(FavoritesViewLoadedModel)
    case loadingError(FavoritesViewErrorModel)
    case deleting([FavoritedProduct])
    case deletingError(FavoritesViewDeletingErrorModel)
}

protocol FavoritesViewModelBuilding: Sendable {
    func buildLoaderModel() -> FavoritesLoaderModel
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModel
}

// MARK: - Model Implementations

struct FavoritesViewModelBuilder: FavoritesViewModelBuilding, Sendable {
    typealias Dependencies = FavoritesLoaderModel.Dependencies & FavoritesViewLoadedModel.Dependencies
    let dependencies: Dependencies
    
    func buildLoaderModel() -> FavoritesLoaderModel {
        return FavoritesLoaderModel(dependencies: dependencies, modelBuilder: self)
    }
    
    func buildFavoritesViewLoadedModel(favorites: [FavoritedProduct]) -> FavoritesViewLoadedModel {
        return FavoritesViewLoadedModel(dependencies: dependencies, modelBuilder: self, favorites: favorites)
    }
}

struct FavoritesLoaderModel: Equatable, Sendable {
    typealias Dependencies = FavoritesRepositoryDependency

    static func == (lhs: FavoritesLoaderModel, rhs: FavoritesLoaderModel) -> Bool {
        // This is just to help with automatic conformance with Equatable on FavoritesViewState
        // Normally you would be more thorough
        true
    }
    
    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    
    func loadFavorites() -> StateSequence<FavoritesViewState> {
        StateSequence(
            { .loading },
            { await fetchFavorites() }
        )
    }
    
    @concurrent
    private func fetchFavorites() async -> FavoritesViewState {
        do {
            let favorites = try await dependencies.favoritesRepository.getFavoritedProducts()
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

final class FavoritesViewLoadedModel: @unchecked Sendable, Equatable {
    typealias Dependencies = FavoritesRepositoryDependency

    static func == (lhs: FavoritesViewLoadedModel, rhs: FavoritesViewLoadedModel) -> Bool {
        lhs.favorites == rhs.favorites
    }

    let dependencies: Dependencies
    let modelBuilder: FavoritesViewModelBuilding
    private(set) var favorites: [FavoritedProduct]
    private var favoritesListChangeStreamTask: Task<Void, Never>?
    
    init(dependencies: Dependencies, modelBuilder: FavoritesViewModelBuilding, favorites: [FavoritedProduct]) {
        self.dependencies = dependencies
        self.modelBuilder = modelBuilder
        self.favorites = favorites
    }
    
    func startObservingFavoritesListChanges(onUpdate: @Sendable @escaping ([FavoritedProduct]) -> Void) {
        guard favoritesListChangeStreamTask == nil else { return }
        
        favoritesListChangeStreamTask = Task { [dependencies] in
            let stream = await dependencies.favoritesRepository.favoritesListChangeStream()
            for await _ in stream {
                guard !Task.isCancelled else { break }
                do {
                    let updatedFavorites = try await dependencies.favoritesRepository.getFavoritedProducts()
                    onUpdate(updatedFavorites)
                } catch {
                    // If we fail to reload, just continue
                }
            }
        }
    }
    
    func stopObservingFavoritesListChanges() {
        favoritesListChangeStreamTask?.cancel()
        favoritesListChangeStreamTask = nil
    }
    
    func updateFavorites(_ favorites: [FavoritedProduct]) {
        self.favorites = favorites
    }
    
    func delete(productId: Int) -> StateSequence<FavoritesViewState> {
        StateSequence(
            { .deleting(self.favorites.filter({ $0.id != productId })) },
            { await self.performDelete(productId: productId) }
        )
    }
    
    @concurrent
    private func performDelete(productId: Int) async -> FavoritesViewState {
        do {
            try await dependencies.favoritesRepository.removeFavorite(productId: productId)
            let updatedFavorites = try await dependencies.favoritesRepository.getFavoritedProducts()
            self.favorites = updatedFavorites
            return .loaded(self)
        } catch {
            return .deletingError(
                FavoritesViewDeletingErrorModel(
                    favorites: favorites,
                    message: "Failed to delete favorite: \(error)",
                    retry: { await self.retryDelete(productId: productId) },
                    cancel: { .loaded(self) }
                )
            )
        }
    }
    
    @concurrent
    private func retryDelete(productId: Int) async -> FavoritesViewState {
        do {
            try await dependencies.favoritesRepository.removeFavorite(productId: productId)
            let updatedFavorites = try await dependencies.favoritesRepository.getFavoritedProducts()
            self.favorites = updatedFavorites
            return .loaded(self)
        } catch {
            return .deletingError(
                FavoritesViewDeletingErrorModel(
                    favorites: favorites,
                    message: "Failed to delete favorite: \(error)",
                    retry: { await self.retryDelete(productId: productId) },
                    cancel: { .loaded(self) }
                )
            )
        }
    }
}

struct FavoritesViewErrorModel: Equatable, Sendable {
    static func == (lhs: FavoritesViewErrorModel, rhs: FavoritesViewErrorModel) -> Bool {
        lhs.message == rhs.message
    }
    
    let message: String
    let retry: @Sendable () async -> FavoritesViewState
}

struct FavoritesViewDeletingErrorModel: Equatable, Sendable {
    static func == (lhs: FavoritesViewDeletingErrorModel, rhs: FavoritesViewDeletingErrorModel) -> Bool {
        lhs.message == rhs.message && lhs.favorites == rhs.favorites
    }
    
    let favorites: [FavoritedProduct]
    let message: String
    let retry: @Sendable () async -> FavoritesViewState
    let cancel: @Sendable () -> FavoritesViewState
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
