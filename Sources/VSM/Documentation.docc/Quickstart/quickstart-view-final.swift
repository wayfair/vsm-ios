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
                if let errorModel = errorModel {
                    VStack {
                        Text(errorModel.message)
                        Button("Retry") {
                            observe(errorModel.retry())
                        }
                    }
                    .background(Color.white)
                }
            }
        case .loaded(loadedModel: let loadedModel):
            VStack {
                Text(loadedModel.title)
                Text(loadedModel.body)
            }
        }
    }
}
