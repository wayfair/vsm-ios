//
//  StatePublishing.swift
//
//
//  Created by Albert Bori on 1/26/23.
//

import Combine

/// Provides a state publisher for observation
public protocol StatePublishing<State> {
    associatedtype State
    
    /// Publishes the State changes on the main thread
    var publisher: AnyPublisher<State, Never> { get }
}
