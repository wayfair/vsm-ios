struct BlogEntryView: View {
    @ViewState var state: BlogEntryViewState
    
    init(repository: BlogEntryProviding, entryId: Int) {
        let loaderModel = LoaderModel(repository: repository, entryId: entryId)
        let state = BlogEntryViewState.initialized(loaderModel: loaderModel)
        _state = .init(wrappedValue: state)
    }
    
    var body: some View {
        ...
    }
}
