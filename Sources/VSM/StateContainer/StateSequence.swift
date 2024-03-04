//
//  StateSequence.swift
//  
//
//  Created by Albert Bori on 7/21/22.
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
public struct StateSequence<State>: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = State
    
    internal let states: [() async -> State]
    var iterator: IndexingIterator<[() async -> State]>
    
    public init(@ViewStateSequenceBuilder<State> states: () -> [() async -> State]) {
        let computedStateSequence = states()
        
        self.states = computedStateSequence
        iterator = computedStateSequence.makeIterator()
    }
    
    internal init(stateList states: [() async -> State]) {
        self.states = states
        iterator = states.makeIterator()
    }
    
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
