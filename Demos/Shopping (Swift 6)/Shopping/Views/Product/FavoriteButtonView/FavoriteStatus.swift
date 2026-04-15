//
//  FavoriteStatus.swift
//  Shopping
//
//  Created by Bill Dunay on 2/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FavoriteStatus {
    typealias Dependencies = FavoritesRepositoryDependency
    
    @ObservationIgnored
    private let dependencies: Dependencies
    private let productId: Int
    private var observationTask: Task<Void, Never>? = nil
    
    var isProductFavorited: Bool = false
    
    init(dependencies: Dependencies, productId: Int) {
        self.dependencies = dependencies
        self.productId = productId
        
        observationTask = Task {
            let favoriteStatusStream = await dependencies.favoritesRepository.favoriteStatusStream(for: productId)
            for await favoriteStatus in favoriteStatusStream {
                isProductFavorited = favoriteStatus
            }
        }
    }
    
    @MainActor
    deinit {
        observationTask?.cancel()
        observationTask = nil
        Task { [dependencies, productId] in
            await dependencies.favoritesRepository.removeFavoriteStatusStream(for: productId)
        }
    }
}
