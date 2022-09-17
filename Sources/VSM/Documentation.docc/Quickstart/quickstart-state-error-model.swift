enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    
}

protocol LoaderModeling {
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never>
}

protocol ErrorModeling {
    var message: String { get }
    func retry() -> AnyPublisher<BlogEntryViewState, Never>
}
