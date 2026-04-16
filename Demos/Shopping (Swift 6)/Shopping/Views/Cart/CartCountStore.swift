//
//  CartCountStore.swift
//  Shopping
//
//  Created by Bill Dunay on 2/4/26.
//

import SwiftUI

// Create an @Observable wrapper for SwiftUI
@Observable
@MainActor
final class CartCountStore {
    typealias Dependencies = CartRepositoryDependency
    
    @ObservationIgnored
    private let dependencies: Dependencies
    
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?
    
    private(set) var productCount: Int = 0
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        startObserving()
    }
    
    deinit {
        observationTask?.cancel()
    }
    
    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            let cartUpdateStream = await dependencies.cartRepository.cartCountStream().1
            for await cart in cartUpdateStream {
                self.productCount = cart
            }
        }
    }
}
