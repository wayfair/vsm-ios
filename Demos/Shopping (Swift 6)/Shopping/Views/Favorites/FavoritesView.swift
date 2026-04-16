//
//  FavoritesView.swift
//  Shopping
//
//  Created by Albert Bori on 2/18/22.
//

import SwiftUI
import VSM

struct FavoritesView: View {
    typealias Dependencies = FavoritesLoaderModel.Dependencies & FavoritesViewLoadedModel.Dependencies
    @ViewState var state: FavoritesViewState
    @State var showErrorAlert: Bool = false
    
    let dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let loaderModel = FavoritesLoaderModel(
            dependencies: dependencies,
            modelBuilder: FavoritesViewModelBuilder(dependencies: dependencies)
        )
        
        // Console logging enabled for this demo app. Logging is disabled by default.
        _state = .init(wrappedValue: .initialized(loaderModel), observedViewType: Self.self, loggingEnabled: true)
    }
    
    var body: some View {
        ZStack {
            favoritedProductListView(favorites: state.favorites)
            switch state {
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
        .onChange(of: state) { oldStateValue, newStateValue in
            if case .deletingError = newStateValue {
                showErrorAlert = true
            }
        }
        .onAppear {
            if case .initialized(let loaderModel) = state {
                $state.observe(loaderModel.loadFavorites())
            }
        }
        .onChange(of: state) { _, newState in
            // Start observing the stream when we transition to loaded state
            if case .loaded(let loadedModel) = newState {
                loadedModel.startObservingFavoritesListChanges { [loadedModel] updatedFavorites in
                    loadedModel.updateFavorites(updatedFavorites)
                    $state.observe(.loaded(loadedModel))
                }
            }
        }
    }
    
    func favoritedProductListView(favorites: [FavoritedProduct]) -> some View {
        List(favorites, id: \.id) { favorite in
            Text(favorite.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if case .loaded(let loadedModel) = state {
                        Button(role: .destructive) {
                            $state.observe(loadedModel.delete(productId: favorite.id))
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
            .accessibilityIdentifier("Processing...")
    }
    
    func errorView(_ errorModel: FavoritesViewErrorModel) -> some View {
        VStack {
            Text("Oops!").font(.title)
            Text(errorModel.message)
            Button("Retry") {
                Task {
                    await $state.observe(errorModel.retry())
                }
            }
        }
    }
    
    @ViewBuilder
    func deletingErrorView(_ deletingErrorModel: FavoritesViewDeletingErrorModel) -> some View {
        if #available(iOS 15, *) {
            VStack { }
                .alert("Oops!", isPresented: $showErrorAlert) {
                    Button("Retry") {
                        Task {
                            await $state.observe(deletingErrorModel.retry())
                        }
                    }
                    Button("Cancel") {
                        $state.observe(deletingErrorModel.cancel())
                    }
                } message: {
                    Text(deletingErrorModel.message)
                }
        } else {
            VStack { }
                .alert(isPresented: $showErrorAlert) {
                    Alert(title: Text("Oops!"),
                          message: Text(deletingErrorModel.message),
                          primaryButton: .default(Text("Retry"), action: {
                              Task {
                                  await $state.observe(deletingErrorModel.retry())
                              }
                          }),
                          secondaryButton: .default(Text("Cancel"), action: { $state.observe(deletingErrorModel.cancel()) }))
                }
        }
    }
}

// MARK: - Test Support

extension FavoritesView {
    init(state: FavoritesViewState, dependencies: Dependencies = MockAppDependencies.noOp()) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: state)
    }
}

// MARK: - Previews

struct FavoritesView_Previews: PreviewProvider {
    static var someFavorites: [FavoritedProduct] = [
        .init(id: 1, name: "Product One"),
        .init(id: 2, name: "Product Two")
    ]
    
    static var previews: some View {
        let favorites = someFavorites
        
        NavigationView {
            FavoritesView(state: .loading)
        }
        .previewDisplayName("loading State")
        
        NavigationView {
            FavoritesView(state: .loaded(
                FavoritesViewLoadedModel(dependencies: MockAppDependencies.noOp(),
                                         modelBuilder: FavoritesViewModelBuilder(dependencies: MockAppDependencies.noOp()), favorites: [])
            ))
        }
        .previewDisplayName("loaded Empty State")
        
        NavigationView {
            FavoritesView(state: .loaded(
                FavoritesViewLoadedModel(
                    dependencies: MockAppDependencies.noOp(),
                    modelBuilder: FavoritesViewModelBuilder(dependencies: MockAppDependencies.noOp()),
                    favorites: favorites)
            ))
        }
        .previewDisplayName("loaded Some Data State")
        
        NavigationView {
            FavoritesView(state: .loadingError(FavoritesViewErrorModel(message: "Loading Error!", retry: { .loading })))
        }
        .previewDisplayName("loadingError State")
        
        NavigationView {
            FavoritesView(state: .deleting(favorites))
        }
        .previewDisplayName("deleting State")
        
        NavigationView {
            FavoritesView(state: .deletingError(
                FavoritesViewDeletingErrorModel(favorites: favorites,
                                                message: "Deleting Error!",
                                                retry: { .loading },
                                                cancel: { .deleting(favorites) })
            ))
        }
        .previewDisplayName("deletingError State")
    }
}
