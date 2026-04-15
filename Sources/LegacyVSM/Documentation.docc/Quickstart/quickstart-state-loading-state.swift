enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    
}

protocol LoaderModeling {
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never>
}

protocol ErrorModeling {
    
    
}
