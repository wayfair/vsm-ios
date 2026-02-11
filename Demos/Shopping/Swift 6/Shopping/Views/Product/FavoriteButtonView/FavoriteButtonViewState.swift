//
//  FavoriteButtonViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum FavoriteButtonViewState: Sendable, Equatable {
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

struct FavoriteInfoLoaderModel: Sendable {
    typealias Dependencies = FavoritesRepositoryDependency & FavoriteButtonLoadedModel.Dependencies
    
    func getFavoriteStatus(dependencies: Dependencies, product: ProductDetail) -> StateSequence<FavoriteButtonViewState> {
        StateSequence(
            { .loading },
            { await fetchingFavoriteStatus(dependencies: dependencies, product: product) }
        )
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
final class FavoriteButtonLoadedModel: @unchecked Sendable {
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
    
    subscript<T>(dynamicMember keyPath: KeyPath<FavoriteButtonLoadedModel, T>) -> T {
        self[keyPath: keyPath]
    }
    
    func toggleFavorite() -> StateSequence<FavoriteButtonViewState> {
        StateSequence(
            { .loading },
            { await self.setFavoriteState() }
        )
    }
    
    func startObservingFavoriteStatusChanges(onUpdate: @Sendable @escaping (Bool) -> Void) {
        guard favoriteStatusStreamTask == nil else { return }
        
        favoriteStatusStreamTask = Task { [dependencies, product] in
            let stream = await dependencies.favoritesRepository.favoriteStatusStream(for: product.id)
            for await isFavorited in stream {
                guard !Task.isCancelled else { break }
                onUpdate(isFavorited)
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
