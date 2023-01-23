//
//  StateSequence.swift
//  
//
//  Created by Albert Bori on 7/21/22.
//

import Foundation

/// Emits multiple `State`s as an `AsyncSequence`
///
/// Usable with ``StateContainer/observe(_:)-4pebt`` (found in ``StateContainer``)
///
/// Example Usage
///
/// ```swift
/// func load() -> StateSequence
///     StateSequence({ .loading }, { await .loaded(getData()) })
/// }
/// ```
public struct StateSequence<State>: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = State
    
    let states: [() async -> State]
    var iterator: IndexingIterator<[() async -> State]>
    
    public init(_ states: () async -> State...) {
        self.states = states
        iterator = states.makeIterator()
    }
    
    mutating public func next() async throws -> State? {
        guard !Task.isCancelled else { return nil }
        return await iterator.next()?()
    }
    
    public func makeAsyncIterator() -> Self { self }
}
