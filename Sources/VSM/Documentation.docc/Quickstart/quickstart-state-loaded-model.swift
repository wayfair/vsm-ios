enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    case loaded(loadedModel: LoadedModeling)
}

protocol LoaderModeling {
    func loadEntry() -> StateSequence<BlogEntryViewState>
}

protocol ErrorModeling {
    var message: String { get }
    func retry() -> StateSequence<BlogEntryViewState>
}

protocol LoadedModeling {
    var title: String { get }
    var body: String { get }
}
