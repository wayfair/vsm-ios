//
//  MockBindableStateModel.swift
//  
//
//  Created by Albert Bori on 5/11/22.
//

import Combine
import VSM

/// A pre-defined mock for testing State-Model binding and progression
struct MockBindableStateModel: MutatingCopyable {
    var isEnabled: Bool
    
    func toggleSync(_ enabled: Bool) -> Self {
        return self.copy(mutating: { $0.isEnabled = enabled })
    }
    
    func toggleAsync(_ enabled: Bool) async -> Self {
        return self.copy(mutating: { $0.isEnabled = enabled })
    }
    
    func togglePublisher(_ enabled: Bool) -> AnyPublisher<Self, Never> {
        return Just(self.copy(mutating: { $0.isEnabled = enabled })).eraseToAnyPublisher()
    }
}
