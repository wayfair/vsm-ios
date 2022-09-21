enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    
    
}

protocol LoaderModeling {
    func loadEntry() -> AnyPublisher<BlogEntryViewState, Never>
}
