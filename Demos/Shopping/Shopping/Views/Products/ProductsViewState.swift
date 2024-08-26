//
//  ProductsViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum ProductsViewState {
    case initialized(ProductsLoaderModeling)
    case loading
    case loaded(ProductsLoadedModeling)
    case error(message: String, retry: () -> AnyPublisher<ProductsViewState, Never>)
}

protocol ProductsLoaderModeling {
    func loadProducts() -> AnyPublisher<ProductsViewState, Never>
}

protocol ProductsLoadedModeling {
    var products: [GridProduct] { get }
    var productDetailId: Int? { get }
    
    func showProductDetail(id: Int) -> ProductsViewState
    nonisolated func refreshProducts() async -> ProductsViewState
    func refreshProducts_SingleValuePublisher() -> AnyPublisher<ProductsViewState, Never>
    func refreshProducts_MultiValuePublisher() -> AnyPublisher<ProductsViewState, Never>
}

// MARK: - Model Implementations

struct ProductsLoaderModel: ProductsLoaderModeling {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    
    func loadProducts() -> AnyPublisher<ProductsViewState, Never> {
        let statePublisher = Just(ProductsViewState.loading)
        let productsPublisher = dependencies.productRepository.getGridProducts()
            .map { products in ProductsViewState.loaded(ProductsLoadedModel(dependencies: dependencies, products: products)) }
            .catch { error in Just(ProductsViewState.error(message: "\(error)", retry: { self.loadProducts() })).eraseToAnyPublisher() }
        return statePublisher
            .merge(with: productsPublisher)
            .eraseToAnyPublisher()
    }
}

struct ProductsLoadedModel: ProductsLoadedModeling {
    typealias Dependencies = ProductRepositoryDependency
    
    let dependencies: Dependencies
    let products: [GridProduct]
    var productDetailId: Int? = nil
    
    func showProductDetail(id: Int) -> ProductsViewState {
        var mutableCopy = self
        mutableCopy.productDetailId = id
        return .loaded(mutableCopy)
    }
    
    nonisolated func refreshProducts() async -> ProductsViewState {
        do {
            let products = try await dependencies.productRepository.getGridProductsAsync()
            return .loaded(
                ProductsLoadedModel(
                    dependencies: dependencies,
                    products: products,
                    productDetailId: productDetailId
                )
            )
            
        } catch {
            return .error(
                message: error.localizedDescription,
                retry: {
                    Just(
                        .initialized(ProductsLoaderModel(dependencies: dependencies))
                    )
                    .eraseToAnyPublisher()
                })
        }
    }
    
    func refreshProducts_SingleValuePublisher() -> AnyPublisher<ProductsViewState, Never> {
        dependencies.productRepository.getGridProducts()
            .map { products in ProductsViewState.loaded(ProductsLoadedModel(dependencies: dependencies, products: products)) }
            .catch { error in Just(ProductsViewState.error(message: "\(error)", retry: { self.refreshProducts_SingleValuePublisher() })).eraseToAnyPublisher() }
            .eraseToAnyPublisher()
    }
    
    func refreshProducts_MultiValuePublisher() -> AnyPublisher<ProductsViewState, Never> {
        let secondProductsResult = dependencies.productRepository.getGridProducts(addingExtra: true)
            .map { products in ProductsViewState.loaded(ProductsLoadedModel(dependencies: dependencies, products: products)) }
            .catch { error in Just(ProductsViewState.error(message: "\(error)", retry: { self.refreshProducts_SingleValuePublisher() })).eraseToAnyPublisher() }
            .delay(for: 3, scheduler: DispatchQueue.global())
        return refreshProducts_SingleValuePublisher()
            .merge(with: secondProductsResult)
            .eraseToAnyPublisher()
    }
}
