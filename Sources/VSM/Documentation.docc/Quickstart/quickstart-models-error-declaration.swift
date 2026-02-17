struct ErrorModel: ErrorModeling {
    let message: String
    
    func retry() -> StateSequence<BlogEntryViewState> {
        
    }
}
