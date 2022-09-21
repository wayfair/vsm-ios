struct BlogEntry: Decodable {
    let id: Int
    let title: String
    let body: String
}

protocol BlogEntryProviding {
    func loadEntry(entryId: Int) -> AnyPublisher<BlogEntry, Error>
}

class BlogEntryRepository: BlogEntryProviding {
    func loadEntry(entryId: Int) -> AnyPublisher<BlogEntry, Error> {
        let urlString = "https://blog-endpoint/\(entryId)"
        guard let url = URL(string: urlString) else {
            return Fail(URLError(.badURL))
                .eraseToAnyPublisher()
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap() { element -> Data in
                guard let httpResponse = element.response as? HTTPURLResponse,
                    httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                return element.data
                }
            .decode(type: BlogEntry.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
