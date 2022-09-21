enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    case loaded(loadedModel: LoadedModeling)
}

protocol LoaderModeling {
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never>
}

protocol ErrorModeling {
    var message: String { get }
    func retry() -> AnyPublisher<BlogEntryViewState, Never>
}

protocol LoadedModeling {
    var title: String { get }
    var body: String { get }
}
