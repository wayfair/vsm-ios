//
//  FavoriteButtonView.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import SwiftUI
import VSM

struct FavoriteButtonView: View, ViewStateRendering {
    typealias Dependencies = FavoriteInfoLoaderModel.Dependencies & FavoriteButtonLoadedModel.Dependencies
    let dependencies: Dependencies
    let productId: Int
    let productName: String
    @StateObject var container: StateContainer<FavoriteButtonViewState> = .init(state: .initialized(FavoriteInfoLoaderModel()))
    
    var isLoading: Bool {
        switch container.state {
        case .initialized, .loading, .error:
            return true
        default:
            return false
        }
    }
    
    init(dependencies: Dependencies, productId: Int, productName: String) {
        self.dependencies = dependencies
        self.productId = productId
        self.productName = productName
    }
    
    var body: some View {
        Button(action: {
            if case .loaded(let loadedModel) = container.state {
                loadedModel.toggleFavorite()
            }
        }) {
            Image(systemName: getSystemImageName())
                .foregroundColor(isLoading ? .gray : .blue)
                .opacity(isLoading ? 0.5 : 1)
        }
        .disabled(isLoading)
        .onAppear {
            if case .initialized(let loaderModel) = container.state {
                container.observe(loaderModel.loadFavoriteInfo(dependencies: dependencies, productId: productId, productName: productName))
            }
        }
    }
    
    func getSystemImageName() -> String {
        switch container.state {
        case .initialized, .loading:
            return "heart"
        case .loaded(let loadedModel):
            return loadedModel.isFavorite ? "heart.fill" : "heart"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Test Support

extension FavoriteButtonView {
    init(state: FavoriteButtonViewState, dependencies: Dependencies = MockAppDependencies.noOp) {
        self.dependencies = dependencies
        self.productId = 0
        self.productName = ""
        _container = .init(state: state)
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
                productId: 1,
                productName: "",
                isFavorite: false)
        ))
        .previewDisplayName("loaded Not-Favorite State")
        
        FavoriteButtonView(state: .loaded(
            FavoriteButtonLoadedModel(
                dependencies: MockAppDependencies.noOp,
                productId: 1,
                productName: "",
                isFavorite: true)
        ))
        .previewDisplayName("loaded Favorite State")
        
        FavoriteButtonView(state: .error)
            .previewDisplayName("error State")
    }
}
