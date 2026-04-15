struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    @StateSequenceBuilder
    func loadEntry() -> StateSequence<BlogEntryViewState> {
        BlogEntryViewState.loading(errorModel: nil)
        Next { await self.fetchEntry() }
    }
    
    @concurrent
    private func fetchEntry() async -> BlogEntryViewState {
        do {
            let blogEntry = try await repository.loadEntry(entryId: entryId)
            let loadedModel = LoadedModel(title: blogEntry.title, body: blogEntry.body)
            return .loaded(loadedModel: loadedModel)
        } catch {
            let errorModel = ErrorModel(
                repository: repository,
                entryId: entryId,
                message: error.localizedDescription
            )
            return .loading(errorModel: errorModel)
        }
    }
}
