struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> StateSequence<BlogEntryViewState> {
        StateSequence(
            first: .loading(errorModel: nil)
        )
    }
}
