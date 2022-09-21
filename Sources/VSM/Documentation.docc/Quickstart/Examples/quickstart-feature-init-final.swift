struct BlogEntryView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogEntryViewState>
    
    init(repository: BlogEntryProviding, entryId: Int) {
        let loaderModel = LoaderModel(repository: repository, entryId: entryId)
        let state = BlogEntryViewState.initialized(loaderModel: loaderModel)
        _container = .init(state: state)
    }
    
    var body: some View {
        ...
    }
}
