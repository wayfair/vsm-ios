//
//  StateSequence.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

import Foundation

/// Emits multiple `State`s as an `AsyncSequence`
///
/// Usable with ``StateObserving/observeAsync(_:)-44uer`` (found in ``StateContainer``)
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
    
    let states: [() async -> State]
    var iterator: IndexingIterator<[() async -> State]>
    
    public init(_ states: () async -> State...) {
        self.states = states
        iterator = states.makeIterator()
    }
    
    mutating public func next() async -> State? {
        guard !Task.isCancelled else { return nil }
        return await iterator.next()?()
    }
    
    public func makeAsyncIterator() -> Self { self }
}
