//
//  ProductCardState.swift
//  LazyHostedStateDemo
//
//  Card state machine, from the handoff example. Shared by both ownership modes.
//

import Foundation
import VSM

// MARK: - Card: states

enum ProductCardViewState: Sendable {
    case initialized(ProductCardLoaderModel)
    case loading(ProductSummary)
    case loaded(ProductCardLoadedModel)
    case loadingError(ProductCardErrorModel)

    /// Every state carries the summary from the feed, so the card can show the name immediately.
    var summary: ProductSummary {
        switch self {
        case .initialized(let model): model.summary
        case .loading(let summary): summary
        case .loaded(let model): model.summary
        case .loadingError(let model): model.summary
        }
    }
}

// MARK: - Card: models

struct ProductCardLoaderModel: Sendable {
    let summary: ProductSummary
    let repository: any ProductRepository

    @StateSequenceBuilder
    func load() -> StateSequence<ProductCardViewState> {
        ProductCardViewState.loading(summary)
        Next { await fetchDetails() }
    }

    @concurrent
    private func fetchDetails() async -> ProductCardViewState {
        do {
            let details = try await repository.fetchDetails(for: summary.id)
            return .loaded(ProductCardLoadedModel(
                summary: summary,
                details: details,
                isFavorite: details.isFavorite,
                repository: repository
            ))
        } catch {
            return .loadingError(ProductCardErrorModel(
                summary: summary,
                message: "Couldn't load details",
                repository: repository
            ))
        }
    }
}

struct ProductCardLoadedModel: Sendable, MutatingCopyable {
    let summary: ProductSummary
    let details: ProductDetails
    var isFavorite: Bool
    let repository: any ProductRepository

    /// Per-row interactive state. Favorite a card, scroll it far off screen, and scroll back:
    /// it is still favorited and nothing is refetched, because the container was retained.
    @StateSequenceBuilder
    func toggleFavorite() -> StateSequence<ProductCardViewState> {
        ProductCardViewState.loaded(copy(mutatingPath: \.isFavorite, value: !isFavorite))   // optimistic, synchronous
        Next { await persistFavorite(!isFavorite) }
    }

    @concurrent
    private func persistFavorite(_ newValue: Bool) async -> ProductCardViewState {
        do {
            try await repository.setFavorite(newValue, for: summary.id)
            return .loaded(copy(mutatingPath: \.isFavorite, value: newValue))
        } catch {
            return .loaded(self)   // revert the optimistic change
        }
    }
}

struct ProductCardErrorModel: Sendable {
    let summary: ProductSummary
    let message: String
    let repository: any ProductRepository

    func retry() -> StateSequence<ProductCardViewState> {
        ProductCardLoaderModel(summary: summary, repository: repository).load()
    }
}
