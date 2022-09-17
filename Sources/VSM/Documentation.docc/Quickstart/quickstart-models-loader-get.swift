struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never> {
        Just(BlogEntryViewState.loading(errorModel: nil))
            .eraseToAnyPublisher()
    }
    
    func getBlogEntry() -> AnyPublisher<BlogEntryViewState, Never> {
        repository.loadEntry(entryId: entryId)
            .eraseToAnyPublisher()
    }
}
