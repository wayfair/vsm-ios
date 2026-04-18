//
//  FavoriteButtonViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum FavoriteButtonViewState: Equatable {
    case initialized(FavoriteInfoLoaderModel)
    case loading
    case loaded(FavoriteButtonLoadedModel)
    case error
    
    static func == (lhs: FavoriteButtonViewState, rhs: FavoriteButtonViewState) -> Bool {
        switch (lhs, rhs) {
        case (.initialized, .initialized):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsModel), .loaded(let rhsModel)):
            return lhsModel.product.id == rhsModel.product.id && lhsModel.isFavorite == rhsModel.isFavorite
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Model Implementations

struct FavoriteInfoLoaderModel {
    typealias Dependencies = FavoritesRepositoryDependency & FavoriteButtonLoadedModel.Dependencies
    
    @StateSequenceBuilder
    func getFavoriteStatus(dependencies: Dependencies, product: ProductDetail) -> StateSequence<FavoriteButtonViewState> {
        FavoriteButtonViewState.loading
        Next { await fetchingFavoriteStatus(dependencies: dependencies, product: product) }
    }
    
    @concurrent
    private func fetchingFavoriteStatus(dependencies: Dependencies, product: ProductDetail) async -> FavoriteButtonViewState {
        do {
            return .loaded(
                FavoriteButtonLoadedModel(
                    dependencies: dependencies,
                    product: product,
                    isFavorite: try await dependencies.favoritesRepository.isFavorited(productId: product.id)
                )
            )
        } catch {
            return .error
        }
    }
}

@dynamicMemberLookup
final class FavoriteButtonLoadedModel {
    typealias Dependencies = FavoritesRepositoryDependency
    
    let dependencies: Dependencies
    let product: ProductDetail
    private(set) var isFavorite: Bool
    private var favoriteStatusStreamTask: Task<Void, Never>?
    
    init(dependencies: Dependencies, product: ProductDetail, isFavorite: Bool) {
        self.dependencies = dependencies
        self.product = product
        self.isFavorite = isFavorite
    }
    
    deinit {
        favoriteStatusStreamTask?.cancel()
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<FavoriteButtonLoadedModel, T>) -> T {
        self[keyPath: keyPath]
    }
    
    @StateSequenceBuilder
    func toggleFavorite() -> StateSequence<FavoriteButtonViewState> {
        FavoriteButtonViewState.loading
        Next { await self.setFavoriteState() }
    }
    
    /// Updates are delivered on the main actor so this callback may capture UI / view-model types
    /// without `Sendable` or `sending`; the stream loop stays off the main actor between yields.
    func startObservingFavoriteStatusChanges(onUpdate: @escaping @MainActor (Bool) -> Void) {
        guard favoriteStatusStreamTask == nil else { return }

        let productId = product.id
        let favoritesRepository = dependencies.favoritesRepository
        favoriteStatusStreamTask = Task {
            let stream = await favoritesRepository.favoriteStatusStream(for: productId)
            for await isFavorited in stream {
                guard !Task.isCancelled else { break }
                await onUpdate(isFavorited)
            }
        }
    }
    
    func stopObservingFavoriteStatusChanges() {
        favoriteStatusStreamTask?.cancel()
        favoriteStatusStreamTask = nil
    }
    
    func updateFavoriteStatus(isFavorited: Bool) {
        self.isFavorite = isFavorited
    }
    
    @concurrent
    private func setFavoriteState() async -> FavoriteButtonViewState {
        do {
            if isFavorite {
                try await dependencies.favoritesRepository.removeFavorite(productId: product.id)
                self.isFavorite = false
                return .loaded(self)
            } else {
                try await dependencies.favoritesRepository.addFavorite(productId: product.id, name: product.name)
                self.isFavorite = true
                return .loaded(self)
            }
        } catch {
            return .error
        }
    }
}
