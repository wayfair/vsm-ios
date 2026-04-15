struct BlogEntryView: View {
    @LegacyViewState var state: BlogEntryViewState
    
    var body: some View {
        switch state {
        case .initialized(loaderModel: let loaderModel):
            ProgressView()
                .onAppear() {
                    $state.observe(loaderModel.load())
                }
        }
    }
}
