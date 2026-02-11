//
//  FavoriteButtonView.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import SwiftUI
import VSM

struct FavoriteButtonView: View {
    typealias Dependencies = FavoriteInfoLoaderModel.Dependencies & FavoriteButtonLoadedModel.Dependencies
    let dependencies: Dependencies
    let product: ProductDetail
    
    // Console logging enabled for this demo app. Logging is disabled by default.
    @ViewState(observedViewType: Self.self, loggingEnabled: true)
    var state: FavoriteButtonViewState = .initialized(FavoriteInfoLoaderModel())
    
    var isLoading: Bool {
        switch state {
        case .initialized, .loading, .error:
            return true
        default:
            return false
        }
    }
    
    init(dependencies: Dependencies, product: ProductDetail) {
        self.dependencies = dependencies
        self.product = product
    }
    
    var body: some View {
        Button(action: {
            if case .loaded(let loadedModel) = state {
                $state.observe(loadedModel.toggleFavorite())
            }
        }) {
            Image(systemName: getSystemImageName())
                .foregroundColor(isLoading ? .gray : .blue)
                .opacity(isLoading ? 0.5 : 1)
        }
        .accessibilityIdentifier(getAccessibilityId())
        .disabled(isLoading)
        .onAppear {
            if case .initialized(let loaderModel) = state {
                $state.observe(loaderModel.getFavoriteStatus(dependencies: dependencies, product: product))
            }
        }
        .onChange(of: state) { _, newState in
            // Start observing the stream when we transition to loaded state
            if case .loaded(let loadedModel) = newState {
                loadedModel.startObservingFavoriteStatusChanges { [loadedModel] isFavorited in
                    loadedModel.updateFavoriteStatus(isFavorited: isFavorited)
                    Task { @MainActor in
                        $state.observe(.loaded(loadedModel))
                    }
                }
            }
        }
    }
    
    func getSystemImageName() -> String {
        switch state {
        case .initialized, .loading:
            return "heart"
        case .loaded(let loadedModel):
            return loadedModel.isFavorite ? "heart.fill" : "heart"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    func getAccessibilityId() -> String {
        switch state {
        case .initialized, .loading:
            return "Inactive Favorite Button"
        case .loaded(let loadedModel):
            return loadedModel.isFavorite ? "Unfavorite Button" : "Favorite Button"
        case .error:
            return "Error Loading Favorite Button"
        }
    }
}

// MARK: - Test Support

extension FavoriteButtonView {
    init(state: FavoriteButtonViewState, dependencies: Dependencies = MockAppDependencies.noOp) {
        self.dependencies = dependencies
        self.product = .init(
            id: 1,
            name: "Ottoman",
            price: 199.99,
            imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/03696184/c_crop_resize_zoom-h300-w300%5Ecompr-r85/5729/57294814/default_name.jpg")!,
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula."
        )
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct FavoriteButtonView_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteButtonView(state: .initialized(FavoriteInfoLoaderModel()))
            .previewDisplayName("initialized State")
        
        FavoriteButtonView(state: .loading)
            .previewDisplayName("loading State")
        
        FavoriteButtonView(state: .loaded(
            FavoriteButtonLoadedModel(
                dependencies: MockAppDependencies.noOp,
                product: .init(
                    id: 1,
                    name: "Ottoman",
                    price: 199.99,
                    imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/03696184/c_crop_resize_zoom-h300-w300%5Ecompr-r85/5729/57294814/default_name.jpg")!,
                    description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula."
                ),
                isFavorite: false)
        ))
        .previewDisplayName("loaded Not-Favorite State")
        
        FavoriteButtonView(state: .loaded(
            FavoriteButtonLoadedModel(
                dependencies: MockAppDependencies.noOp,
                product: .init(
                    id: 1,
                    name: "Ottoman",
                    price: 199.99,
                    imageURL: URL(string: "https://secure.img1-fg.wfcdn.com/im/03696184/c_crop_resize_zoom-h300-w300%5Ecompr-r85/5729/57294814/default_name.jpg")!,
                    description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer ornare sit amet lacus eget vehicula."
                ),
                isFavorite: true)
        ))
        .previewDisplayName("loaded Favorite State")
        
        FavoriteButtonView(state: .error)
            .previewDisplayName("error State")
    }
}
