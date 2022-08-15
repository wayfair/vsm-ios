//
//  StateObject+StateInit.swift
//  
//
//  Created by Albert Bori on 6/6/22.
//

import Foundation
import SwiftUI

@available(macOS 11.0, *)
@available(iOS 14.0, *)
public extension StateObject {
    
    /// VSM convenience initializer for creating a `StateObject<StateContainer<State>>` directly from a `StateContainer.State` value.
    /// Replaces `_container = .init(wrappedValue: StateContainer(state: ...))`
    /// - Parameter state: The value for the desired `StateContainer.State`
    init<ContainedState>(state: ContainedState) where ObjectType: StateContainer<ContainedState> {
        self.init(wrappedValue: ObjectType(state: state))
    }
}
