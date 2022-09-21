struct ErrorModel: ErrorModeling {
    let message: String
    
    func retry() -> AnyPublisher<BlogEntryViewState, Never> {
        
    }
}
