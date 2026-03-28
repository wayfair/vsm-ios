//
//  AnyPublisher+JustEmpty.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

extension AnyPublisher {
    
    /// Convenience function for generating an inert instance of the given `AnyPublisher` type.
    /// Useful for mocking publisher output
    static func empty() -> Self {
        return Empty<Output, Failure>().eraseToAnyPublisher()
    }
}

extension AnyPublisher where Failure: Error {
    /// Bridges a Combine publisher to async/await by awaiting the first value and then cancelling the subscription.
    func asyncAwait() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self.first().sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    case .finished:
                        break
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                }
            )
        }
    }
}

extension AnyPublisher where Output == AsyncDataState<[FavoritedProduct], Error>, Failure == Never {
    /// Awaits the first `.loaded` value from an AsyncDataState publisher, skipping `.loading` states.
    func asyncFirstLoaded() async throws -> [FavoritedProduct] {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self
                .compactMap { state -> Result<[FavoritedProduct], Error>? in
                    switch state {
                    case .loading:
                        return nil
                    case .loaded(let value):
                        return .success(value)
                    case .error(let error):
                        return .failure(error)
                    }
                }
                .first()
                .sink { _ in
                    cancellable?.cancel()
                } receiveValue: { result in
                    continuation.resume(with: result)
                }
        }
    }
}
