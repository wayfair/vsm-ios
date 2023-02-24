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
    
    /// Publishes the state changes on the main thread
    @available(*, deprecated, renamed: "didSetPublisher", message: "Renamed to didSetPublisher and will be removed in a future version")
    var publisher: AnyPublisher<State, Never> { get }
    
    /// Publishes the state changes on the main thread before the current state is updated
    ///
    /// SwiftUI views should generally use this publisher when using `onReceive` to observe the state, especially if modifying other view properties in the `onReceive` closure.
    ///
    /// Views (SwiftUI & UIKit) can use this publisher to compare the current state with the future state to determine what view updates are necessary.
    var willSetPublisher: AnyPublisher<State, Never> { get }
    /// Publishes the state changes on the main thread after the current state is updated
    var didSetPublisher: AnyPublisher<State, Never> { get }
}
