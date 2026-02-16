struct BlogEntry: Decodable {
    let id: Int
    let title: String
    let body: String
}

protocol BlogEntryProviding {
    func loadEntry(entryId: Int) -> AnyPublisher<BlogEntry, Error>
}
