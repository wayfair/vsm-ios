struct BlogEntryView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogEntryViewState>
    
    var body: some View {
        switch state {
        case .initialized(loaderModel: let loaderModel):
            ProgressView()
        }
    }
}
