struct BlogEntryView: View {
    @LegacyViewState var state: BlogEntryViewState
    
    init(repository: BlogEntryProviding, entryId: Int) {
        
    }
    
    var body: some View {
        ...
    }
}
