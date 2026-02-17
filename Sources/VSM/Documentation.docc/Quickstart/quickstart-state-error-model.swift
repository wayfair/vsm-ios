enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    
}

protocol LoaderModeling {
    func loadEntry() -> StateSequence<BlogEntryViewState>
}

protocol ErrorModeling {
    var message: String { get }
    func retry() -> StateSequence<BlogEntryViewState>
}
