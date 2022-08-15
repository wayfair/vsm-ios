//
//  StateContainer+Debug.swift
//  This file provides `StateContainer.$state` debugging logging behavior when compiling in DEBUG configurations
//
//  Created by Albert Bori on 5/12/22.
//

#if DEBUG

import Combine
import Foundation

public extension StateContainer {
    
    /// Prints all state changes in this `StateContainer`, starting with the current state. ⚠️ Requires DEBUG configuration.
    @available(*, deprecated, message: "FAILS TO COMPILE in non-DEBUG schemas")
    @discardableResult
    func debug() -> Self {
        _StateContainerDebugLogger.register(stateContainer: self)
        return self
    }
}

public extension StateContainer where State == Any {
    
    /// Prints all state changes in every `StateContainer` created after this line. ⚠️ Requires DEBUG configuration.
    @available(*, deprecated, message: "FAILS TO COMPILE in non-DEBUG schemas")
    static func debug() {
        _StateContainerDebugLogger.isLoggingAllStateContainers = true
    }
}

private enum _StateContainerDebugLogger {
    static var isLoggingAllStateContainers: Bool = false
    static var cancellables: Set<AnyCancellable> = []
    
    static func register<State>(stateContainer: StateContainer<State>) {
        let stateContainerName = "\(type(of: stateContainer))"
        stateContainer.$state
            .sink { changedState in
                NSLog("\(stateContainerName).state set to: \(changedState)")
            }
            .store(in: &cancellables)
    }
}

#endif

extension StateContainer {
    func registerForDebugLogging() {
#if DEBUG
        if _StateContainerDebugLogger.isLoggingAllStateContainers {
            _StateContainerDebugLogger.register(stateContainer: self)
        }
#endif
    }
}
