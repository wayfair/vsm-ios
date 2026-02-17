struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> StateSequence<BlogEntryViewState> {
        StateSequence(
            { .loading(errorModel: nil) },
            { await self.fetchEntry() }
        )
    }
    
    @concurrent
    private func fetchEntry() async -> BlogEntryViewState {
        do {
            let blogEntry = try await repository.loadEntry(entryId: entryId)
            let loadedModel = LoadedModel(title: blogEntry.title, body: blogEntry.body)
            return .loaded(loadedModel: loadedModel)
        }
    }
}
