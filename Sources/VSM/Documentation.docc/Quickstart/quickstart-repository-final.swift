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
        let urlString = "https://blog-endpoint/\(entryId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BlogEntry.self, from: data)
    }
}
