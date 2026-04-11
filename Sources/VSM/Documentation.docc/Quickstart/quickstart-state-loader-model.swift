enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    
    
}

protocol LoaderModeling {
    func loadEntry() -> StateSequence<BlogEntryViewState>
}
