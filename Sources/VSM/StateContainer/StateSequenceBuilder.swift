//
//  StateSequenceBuilder.swift
//
//
//  Created by Bill Dunay on 3/4/24.
//

import Foundation

@resultBuilder
public struct ViewStateSequenceBuilder<ViewState> {
    public static func buildBlock(_ components: () async -> ViewState...) -> [() async -> ViewState] {
        components
    }
    
    public static func buildExpression(_ expression: @escaping () async -> ViewState) -> [() async -> ViewState] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [() async -> ViewState]) -> [() async -> ViewState] {
        expression
    }
    
    public static func buildEither(first component: [() async -> ViewState]) -> [() async -> ViewState] {
        component
    }
    
    public static func buildEither(second component: [() async -> ViewState]) -> [() async -> ViewState] {
        component
    }
}

@resultBuilder
public struct StateSequenceBuilder<ViewState> {
    public static func buildBlock(_ components: () async -> ViewState...) -> StateSequence<ViewState> {
        StateSequence(stateList: components)
    }
    
    public static func buildPartialBlock(@ViewStateSequenceBuilder<ViewState> first: () -> [() async -> ViewState]) -> StateSequence<ViewState> {
        StateSequence(states: first)
    }
    
    public static func buildPartialBlock(@ViewStateSequenceBuilder<ViewState> accumulated: () -> [() async -> ViewState], @ViewStateSequenceBuilder<ViewState> next: () -> [() async -> ViewState]) -> StateSequence<ViewState> {
        let firstStates = accumulated()
        let nextStates = next()
        let fullList = firstStates + nextStates
        
        return StateSequence(stateList: fullList)
    }
}
