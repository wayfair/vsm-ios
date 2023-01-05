//
//  FavoritesView.swift
//  Shopping
//
//  Created by Albert Bori on 2/18/22.
//

import SwiftUI
import VSM

struct FavoritesView: View, ViewStateRendering {
    typealias Dependencies = FavoritesLoaderModel.Dependencies & FavoritesViewLoadedModel.Dependencies
    @ObservedObject var container: StateContainer<FavoritesViewState>
    @State var showErrorAlert: Bool = false
    
    init(dependencies: Dependencies) {
        let loaderModel = FavoritesLoaderModel(dependencies: dependencies,
                                                             modelBuilder: FavoritesViewModelBuilder(dependencies: dependencies))
        container = .init(state: .initialized(loaderModel))
        container.observe(loaderModel.loadFavorites())
    }
    
    var body: some View {
        ZStack {
            favoritedProductListView(favorites: container.state.favorites)
            switch container.state {
            case .initialized, .loading:
                ProgressView()
            case .loaded(let loadedModel):
                if loadedModel.favorites.isEmpty {
                    Text("You have no favorite products.")
                }
            case .loadingError(let errorModel):
                errorView(errorModel)
            case .deleting:
                deletingFavoritedProductView()
            case .deletingError(let deletingErrorModel):
                deletingErrorView(deletingErrorModel)
            }
        }
        .navigationTitle("Favorites")
        .onReceive(container.$state) { state in
            if case .deletingError = state {
                showErrorAlert = true
            }
        }
    }
    
    func favoritedProductListView(favorites: [FavoritedProduct]) -> some View {
        List(favorites, id: \.id) { favorite in
            Text(favorite.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if case .loaded(let loadedModel) = container.state {
                        Button(role: .destructive) {
                            container.observe(loadedModel.delete(productId: favorite.id))
                        } label : {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .accessibilityIdentifier("Delete \(favorite.name)")
                    }
                }
                .accessibilityIdentifier(favorite.name + " Row")
        }
    }
    
    func deletingFavoritedProductView() -> some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.75))
            .accessibilityIdentifier("Deleting Progress View")
    }
    
    func errorView(_ errorModel: FavoritesViewErrorModeling) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(errorModel.message)
            Button("Retry") {
                container.observe(errorModel.retry())
            }
        }
    }
    
    @ViewBuilder
    func deletingErrorView(_ deletingErrorModel: FavoritesViewDeletingErrorModeling) -> some View {
        if #available(iOS 15, *) {
            VStack { }
                .alert("Oops!", isPresented: $showErrorAlert) {
                    Button("Retry") {
                        container.observe(deletingErrorModel.retry())
                    }
                    Button("Cancel") {
                        container.observe(deletingErrorModel.cancel())
                    }
                } message: {
                    Text(deletingErrorModel.message)
                }
        } else {
            VStack { }
                .alert(isPresented: $showErrorAlert) {
                    Alert(title: Text("Oops!"),
                          message: Text(deletingErrorModel.message),
                          primaryButton: .default(Text("Retry"), action: { container.observe(deletingErrorModel.retry()) }),
                          secondaryButton: .default(Text("Cancel"), action: { container.observe(deletingErrorModel.cancel()) }))
                }
        }
    }
}

// MARK: - Test Support

extension FavoritesView {
    init(state: FavoritesViewState) {
        container = .init(state: state)
    }
}

// MARK: - Previews

struct FavoritesView_Previews: PreviewProvider {
    static var someFavorites: [FavoritedProduct] = [
        .init(id: 1, name: "Product One"),
        .init(id: 2, name: "Product Two")
    ]
    
    static var previews: some View {
        NavigationView {
            FavoritesView(state: .loading)
        }
        .previewDisplayName("loading State")
        
        NavigationView {
            FavoritesView(state: .loaded(
                FavoritesViewLoadedModel(dependencies: MockAppDependencies.noOp,
                                         modelBuilder: FavoritesViewModelBuilder(dependencies: MockAppDependencies.noOp), favorites: [])
            ))
        }
        .previewDisplayName("loaded Empty State")
        
        NavigationView {
            FavoritesView(state: .loaded(
                FavoritesViewLoadedModel(
                    dependencies: MockAppDependencies.noOp,
                    modelBuilder: FavoritesViewModelBuilder(dependencies: MockAppDependencies.noOp),
                    favorites: someFavorites)
            ))
        }
        .previewDisplayName("loaded Some Data State")
        
        NavigationView {
            FavoritesView(state: .loadingError(FavoritesViewErrorModel(message: "Loading Error!", retry: { .empty() })))
        }
        .previewDisplayName("loadingError State")
        
        NavigationView {
            FavoritesView(state: .deleting(someFavorites))
        }
        .previewDisplayName("deleting State")
        
        NavigationView {
            FavoritesView(state: .deletingError(
                FavoritesViewDeletingErrorModel(favorites: someFavorites,
                                                message: "Deleting Error!",
                                                retry: { .empty() },
                                                cancel: { .empty() })
            ))
        }
        .previewDisplayName("deletingError State")
    }
}
