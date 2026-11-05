//
//  ProductFeedState.swift
//  LazyHostedStateDemo
//
//  Feed state machine, from the handoff example.
//

import Foundation
import VSM

// MARK: - Feed: states

enum ProductFeedViewState: Sendable {
    case initialized(ProductFeedLoaderModel)
    case loading
    case loaded(ProductFeedLoadedModel)
    case loadingError(ProductFeedErrorModel)
}

// MARK: - Feed: models

/// Shared by the loader and error models so both produce identical outcomes.
enum ProductFeedFetching {
    @concurrent
    static func fetchFeedState(using repository: any ProductRepository) async -> ProductFeedViewState {
        do {
            let products = try await repository.fetchFeed()
            return .loaded(ProductFeedLoadedModel(products: products, repository: repository))
        } catch {
            return .loadingError(ProductFeedErrorModel(message: error.localizedDescription, repository: repository))
        }
    }
}

struct ProductFeedLoaderModel: Sendable {
    let repository: any ProductRepository

    @StateSequenceBuilder
    func load() -> StateSequence<ProductFeedViewState> {
        ProductFeedViewState.loading                                         // applied synchronously
        Next { await ProductFeedFetching.fetchFeedState(using: repository) }
    }
}

struct ProductFeedLoadedModel: Sendable {
    let products: [ProductSummary]
    let repository: any ProductRepository

    var productIDs: [ProductSummary.ID] { products.map(\.id) }

    /// Pull-to-refresh. Goes straight from loaded to loaded, so the list stays on screen,
    /// and a failed refresh keeps showing the current products instead of an error screen.
    @concurrent
    func refreshed() async -> ProductFeedViewState {
        do {
            return .loaded(ProductFeedLoadedModel(products: try await repository.fetchFeed(), repository: repository))
        } catch {
            return .loaded(self)
        }
    }
}

struct ProductFeedErrorModel: Sendable {
    let message: String
    let repository: any ProductRepository

    func retry() -> StateSequence<ProductFeedViewState> {
        ProductFeedLoaderModel(repository: repository).load()
    }
}
