//
//  FavoritesRepository.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

protocol FavoritesRepository {
    func updateFromServer()
    func getFavoritesPublisher() -> AnyPublisher<AsyncDataState<[FavoritedProduct], Error>, Never>
    func getFavoriteStatusPublisher(productId: Int) -> AnyPublisher<AsyncDataState<Bool, Error>, Never>
    func addFavorite(productId: Int, name: String) -> AnyPublisher<Void, Error>
    func removeFavorite(productId: Int) -> AnyPublisher<Void, Error>
}

protocol FavoritesRepositoryDependency {
    var favoritesRepository: FavoritesRepository { get }
}

struct FavoritedProduct {
    let id: Int
    let name: String
}

//MARK: - Implementation

class FavoritesDatabase: FavoritesRepository {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    @Published var favoriteProductsDatabase: AsyncDataState<[Int: String], Error> = .loading // Not thread-safe
    private var cancellables = Set<AnyCancellable>()
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        updateFromServer()
    }
        
    func updateFromServer() {
        // Pretend to get products from the server
        DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
            switch self.favoriteProductsDatabase {
            case .loading:
                self.favoriteProductsDatabase = .loaded([:])
            case .loaded(let favorites):
                self.favoriteProductsDatabase = .loaded(favorites)
            case .error:
                break
            }
        }
    }
    
    func getFavoritesPublisher() -> AnyPublisher<AsyncDataState<[FavoritedProduct], Error>, Never> {
        updateFromServer()
        return $favoriteProductsDatabase.map { state in
            state.map { database in
                database.map({ FavoritedProduct(id: $0.0, name: $0.1) })
            }
        }.eraseToAnyPublisher()
    }
    
    func getFavoriteStatusPublisher(productId: Int) -> AnyPublisher<AsyncDataState<Bool, Error>, Never> {
        updateFromServer()
        return $favoriteProductsDatabase.map { state in
            state.map { database in
                database[productId] != nil
            }
        }.eraseToAnyPublisher()
    }
    
    func addFavorite(productId: Int, name: String) -> AnyPublisher<Void, Error> {
        switch favoriteProductsDatabase {
        case .loading, .error:
            break
        case .loaded(var database):
            database[productId] = name
            favoriteProductsDatabase = .loaded(database)
        }
        //Pretend to send this to the server asynchronously
        return Future { promise in
            DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
                promise(.success(Void()))
            }
        }.eraseToAnyPublisher()

    }
    
    func removeFavorite(productId: Int) -> AnyPublisher<Void, Error> {
        switch favoriteProductsDatabase {
        case .loading, .error:
            break
        case .loaded(var database):
            database.removeValue(forKey: productId)
            favoriteProductsDatabase = .loaded(database)
        }
        //Pretend to send this to the server asynchronously
        return Future { promise in
            DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
                promise(.success(Void()))
            }
        }.eraseToAnyPublisher()
    }
}

struct FavoritesDatabaseDependencies: FavoritesDatabase.Dependencies {
    var productRepository: ProductRepository
}

//MARK: Test Support

struct MockFavoritesRepository: FavoritesRepository {
    static var noOp: Self {
        Self.init(
            updateFromServerImpl: { },
            getFavoritesPublisherImpl: { .empty() },
            getFavoriteStatusPublisherImpl: { _ in .empty() },
            addFavoriteImpl: { _, _ in .empty() },
            removeFavoriteImpl: { _ in .empty() }
        )
    }
    
    var updateFromServerImpl: () -> Void
    func updateFromServer() {
        updateFromServerImpl()
    }
    
    var getFavoritesPublisherImpl: () -> AnyPublisher<AsyncDataState<[FavoritedProduct], Error>, Never>
    func getFavoritesPublisher() -> AnyPublisher<AsyncDataState<[FavoritedProduct], Error>, Never> {
        getFavoritesPublisherImpl()
    }
    
    var getFavoriteStatusPublisherImpl: (Int) -> AnyPublisher<AsyncDataState<Bool, Error>, Never>
    func getFavoriteStatusPublisher(productId: Int) -> AnyPublisher<AsyncDataState<Bool, Error>, Never> {
        getFavoriteStatusPublisherImpl(productId)
    }
    
    var addFavoriteImpl: (Int, String) -> AnyPublisher<Void, Error>
    func addFavorite(productId: Int, name: String) -> AnyPublisher<Void, Error> {
        addFavoriteImpl(productId, name)
    }
    
    var removeFavoriteImpl: (Int) -> AnyPublisher<Void, Error>
    func removeFavorite(productId: Int) -> AnyPublisher<Void, Error> {
        removeFavoriteImpl(productId)
    }
}



