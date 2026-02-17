struct ErrorModel: ErrorModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    let message: String
    
    func retry() -> StateSequence<BlogEntryViewState> {
        LoaderModel(repository: repository, entryId: entryId).loadEntry()
    }
}
