struct BlogEntryView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogEntryViewState>
    
    init(repository: BlogEntryProviding, entryId: Int) {
        
    }
    
    var body: some View {
        ...
    }
}
