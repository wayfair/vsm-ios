//
//  StateSequence.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

import Foundation

/// Emits multiple `State`s as an `AsyncSequence`
///
/// Usable with ``StateObserving/observeAsync(_:)`` (found in ``AsyncStateContainer``)
///
/// Example Usage
///
/// ```swift
/// func load() -> StateSequence
///     StateSequence({ .loading }, { await .loaded(getData()) })
/// }
/// ```
public struct StateSequence<State: Sendable>: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = State
    
    let states: [@Sendable () async -> State]
    var iterator: IndexingIterator<[@Sendable () async -> State]>
    
    public init(_ states: @Sendable () async -> State...) {
        self.states = states
        iterator = states.makeIterator()
    }
    
    mutating public func next() async -> State? {
        guard !Task.isCancelled else { return nil }
        return await iterator.next()?()
    }
    
    public func makeAsyncIterator() -> Self { self }
}
