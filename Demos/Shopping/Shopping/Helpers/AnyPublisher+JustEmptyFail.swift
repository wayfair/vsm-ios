//
//  AnyPublisher+JustEmpty.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

extension AnyPublisher {
    /// Convenience function for generating a single-value output instance of the given `AnyPublisher` type.
    /// Useful for mocking publisher output
    static func just(_ output: Output) -> Self {
        return Just(output)
            .setFailureType(to: Failure.self)
            .eraseToAnyPublisher()
    }
    
    /// Convenience function for generating an inert instance of the given `AnyPublisher` type.
    /// Useful for mocking publisher output
    static func empty() -> Self {
        return Empty<Output, Failure>().eraseToAnyPublisher()
    }
    
    static func fail(_ failure: Failure) -> Self {
        return Fail<Output, Failure>(error: failure).eraseToAnyPublisher()
    }
}
