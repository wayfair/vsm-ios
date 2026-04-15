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
        
    }
}
