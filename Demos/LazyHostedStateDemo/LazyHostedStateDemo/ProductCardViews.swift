//
//  ProductCardViews.swift
//  LazyHostedStateDemo
//
//  Two card views that differ only in where the card's AsyncStateContainer lives.
//  Everything visible comes from the shared `ProductCardBody`.
//

import SwiftUI
import VSM

/// Baseline: `@ViewState` keeps the container in SwiftUI `@State`, so SwiftUI discarding the row's
/// state resets the card to `.initialized` and it refetches.
struct BaselineCardView: View {
    @ViewState var state: ProductCardViewState

    init(summary: ProductSummary, repository: any ProductRepository) {
        _state = ViewState(
            wrappedValue: .initialized(ProductCardLoaderModel(summary: summary, repository: repository)),
            observedViewType: BaselineCardView.self,
            signpostsEnabled: true
        )
    }

    var body: some View {
        ProductCardBody(state: state, container: $state)
    }
}

/// Hosted: the container is injected from a `ViewStateStore` owned outside the lazy container.
struct HostedCardView: View {
    @HostedViewState var state: ProductCardViewState

    init(container: AsyncStateContainer<ProductCardViewState>) {
        _state = HostedViewState(container: container)
    }

    var body: some View {
        ProductCardBody(state: state, container: $state)
    }
}

/// The card's appearance and actions, independent of who owns the state.
struct ProductCardBody: View {
    let state: ProductCardViewState
    let container: AsyncStateContainer<ProductCardViewState>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(state.summary.name)
                    .font(.headline)
                details
            }

            Spacer(minLength: 0)

            if case .loaded(let model) = state {
                Button {
                    container.observe(model.toggleFavorite())
                } label: {
                    Image(systemName: model.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(model.isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isFavorite ? "Remove from favorites" : "Add to favorites")
                .accessibilityIdentifier("favorite-\(state.summary.id)")
            }
        }
        // A fixed minimum height keeps row sizes stable across states.
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-\(state.summary.id)")
    }

    @ViewBuilder
    private var details: some View {
        switch state {
        case .initialized(let loaderModel):
            ProgressView()
                .controlSize(.small)
                .onAppear { container.observe(loaderModel.load()) }

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .loaded(let model):
            HStack(spacing: 8) {
                Text(model.details.priceText)
                    .font(.subheadline.weight(.semibold))
                Text(model.details.ratingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .loadingError(let errorModel):
            HStack(spacing: 8) {
                Text(errorModel.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") { container.observe(errorModel.retry()) }
                    .font(.caption)
            }
        }
    }
}
