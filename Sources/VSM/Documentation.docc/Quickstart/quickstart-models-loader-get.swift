struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> StateSequence<BlogEntryViewState> {
        StateSequence(
            first: .loading(errorModel: nil),
            rest: { await self.fetchEntry() }
        )
    }
    
    @concurrent
    private func fetchEntry() async -> BlogEntryViewState {
        
    }
}
