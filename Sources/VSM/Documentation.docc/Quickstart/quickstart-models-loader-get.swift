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
        
    }
}
