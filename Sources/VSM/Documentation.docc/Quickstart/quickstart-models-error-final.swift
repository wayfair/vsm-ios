struct ErrorModel: ErrorModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    let message: String
    
    func retry() -> AnyPublisher<BlogEntryViewState, Never> {
        LoaderModel(repository: repository, entryId: entryId)
            .loadEntry()
    }
}
