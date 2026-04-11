struct BlogEntry: Decodable {
    let id: Int
    let title: String
    let body: String
}

protocol BlogEntryProviding {
    func loadEntry(entryId: Int) async throws -> BlogEntry
}

class BlogEntryRepository: BlogEntryProviding {
    func loadEntry(entryId: Int) async throws -> BlogEntry {
        
    }
}
