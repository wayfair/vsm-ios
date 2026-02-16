struct BlogEntryView: View {
    @ViewState var state: BlogEntryViewState
    
    var body: some View {
        switch state {
        case .initialized(loaderModel: let loaderModel):
            ProgressView()
                .onAppear() {
                    $state.observe(loaderModel.load())
                }
        case .loading(errorModel: let errorModel):
            ZStack {
                ProgressView()
                if let errorModel = errorModel {
                    VStack {
                        Text(errorModel.message)
                        Button("Retry") {
                            $state.observe(errorModel.retry())
                        }
                    }
                    .background(Color.white)
                }
            }
        }
    }
}
