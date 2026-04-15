struct LoaderModel: LoaderModeling {
    let repository: BlogEntryProviding
    let entryId: Int
    
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never> {
        
    }
}
