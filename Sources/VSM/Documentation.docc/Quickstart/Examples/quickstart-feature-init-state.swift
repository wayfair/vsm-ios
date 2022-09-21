struct BlogEntryView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogEntryViewState>
    
    init(repository: BlogEntryProviding, entryId: Int) {
        let loaderModel = LoaderModel(repository: repository, entryId: entryId)
        let state = BlogEntryViewState.initialized(loaderModel: loaderModel)
        
    }
    
    var body: some View {
        ...
    }
}
