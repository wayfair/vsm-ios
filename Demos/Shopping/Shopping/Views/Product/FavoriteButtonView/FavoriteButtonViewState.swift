//
//  FavoriteButtonViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import Combine
import Foundation
import SwiftUI

// MARK: - State & Model Definitions

enum FavoriteButtonViewState {
    case initialized(FavoriteInfoLoaderModel)
    case loading
    case loaded(FavoriteButtonLoadedModel)
    case error
}

// MARK: - Model Implementations

struct FavoriteInfoLoaderModel {
    typealias Dependencies = FavoritesRepositoryDependency & FavoriteButtonLoadedModel.Dependencies
    
    func loadFavoriteInfo(dependencies: Dependencies, productId: Int, productName: String) -> AnyPublisher<FavoriteButtonViewState, Never> {
        return dependencies.favoritesRepository.getFavoriteStatusPublisher(productId: productId)
            .map { favoriteState in
                switch favoriteState {
                case .loading:
                    return FavoriteButtonViewState.loading
                case .loaded(let isFavorite):
                    return FavoriteButtonViewState.loaded(FavoriteButtonLoadedModel(dependencies: dependencies, productId: productId, productName: productName, isFavorite: isFavorite))
                case .error:
                    return FavoriteButtonViewState.error
                }
            }.eraseToAnyPublisher()
    }
}

struct FavoriteButtonLoadedModel {
    typealias Dependencies = FavoritesRepositoryDependency
    let dependencies: Dependencies
    let productId: Int
    let productName: String
    var isFavorite: Bool
    
    func toggleFavorite() {
        if isFavorite {
            _ = dependencies.favoritesRepository.removeFavorite(productId: productId)
        } else {
            _ = dependencies.favoritesRepository.addFavorite(productId: productId, name: productName)
        }
    }
}
