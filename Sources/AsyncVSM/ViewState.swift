//
//  ViewState.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//
import Foundation
import SwiftUI

@MainActor
@propertyWrapper
public struct ViewState<State>: DynamicProperty where State: Sendable {
    public let container: AsyncStateContainer<State>
    
    public var wrappedValue: State {
        get { container.state }
    }
    
    public var projectedValue: AsyncStateContainer<State> { container }
    
    public init(wrappedValue initialState: State) {
        self.container = AsyncStateContainer(state: initialState)
    }
}
