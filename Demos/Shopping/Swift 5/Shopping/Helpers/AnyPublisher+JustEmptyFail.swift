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
