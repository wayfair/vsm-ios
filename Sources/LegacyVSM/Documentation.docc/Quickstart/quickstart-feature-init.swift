struct BlogEntryView: View {
    @ViewState var state: BlogEntryViewState
    
    init(repository: BlogEntryProviding, entryId: Int) {
        
    }
    
    var body: some View {
        ...
    }
}
