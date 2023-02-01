//
//  AtomicStateChangeSubscriber.swift
//
//
//  Created by Albert Bori on 12/8/22.
//

import Combine
import Foundation

class AtomicStateChangeSubscriber<State> {
    private var subscription: AnyCancellable?
    /// This property ensures that if `subscribe` is called while we're still subscribing (recursively), it will not cause an infinite loop.
    private var willSubscribe: Bool = true
    
    /// Subscribes to changes in state. This subscription happens exactly once even if called repeatedly in a multi-threaded environment.
    ///
    /// This is primarily used for wiring up any non-standard state observation, such as within the static subscript of a property wrapper.
    func subscribeOnce(to statePublisher: some Publisher<State, Never>, receivedValue: @escaping (State) -> Void) {
        // Ensure we are subscribing on the main thread for thread safety of shared mutable properties of this object
        if Thread.isMainThread {
            subscribeOnceSynced(to: statePublisher, receivedValue: receivedValue)
        } else {
            DispatchQueue.main.async {
                self.subscribeOnceSynced(to: statePublisher, receivedValue: receivedValue)
            }
        }
    }
    
    private func subscribeOnceSynced(to statePublisher: some Publisher<State, Never>, receivedValue: @escaping (State) -> Void) {
        guard subscription == nil, willSubscribe else { return }
        willSubscribe = false
        subscription = statePublisher
            .sink { state in
                receivedValue(state)
            }
    }
}
