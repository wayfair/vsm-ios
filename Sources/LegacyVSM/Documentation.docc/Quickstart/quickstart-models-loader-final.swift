struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never> {
        Just(BlogEntryViewState.loading(errorModel: nil))
            .merge(with: getBlogEntry())
            .eraseToAnyPublisher()
    }
    
    func getBlogEntry() -> AnyPublisher<BlogEntryViewState, Never> {
        repository.loadEntry(entryId: entryId)
            .map { blogEntry in
                let loadedModel = LoadedModel(
                    title: blogEntry.title,
                    body: blogEntry.body
                )
                return BlogEntryViewState.loaded(loadedModel: loadedModel)
            }
            .catch { error in
                let errorModel = ErrorModel(
                    repository: repository,
                    entryId: entryId,
                    message: error.localizedDescription
                )
                return Just(BlogEntryViewState.loading(errorModel: errorModel))
            }
            .eraseToAnyPublisher()
    }
}
