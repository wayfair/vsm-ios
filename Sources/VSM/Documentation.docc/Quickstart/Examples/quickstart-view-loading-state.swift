struct BlogEntryView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogEntryViewState>
    
    var body: some View {
        switch state {
        case .initialized(loaderModel: let loaderModel):
            ProgressView()
                .onAppear() {
                    observe(loaderModel.load())
                }
        case .loading(errorModel: let errorModel):
            ZStack {
                ProgressView()
            }
        }
    }
}
