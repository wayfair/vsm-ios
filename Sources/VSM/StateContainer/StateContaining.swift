//
//  StateContaining.swift
//
//
//  Created by Albert Bori on 1/23/23.
//

import Combine

#if canImport(SwiftUI)

import SwiftUI

/// Combines commonly used state management protocols into a single protocol
public protocol StateContaining<State>: StateObserving, StatePublishing, StateBinding { }

#else

/// Combines commonly used state management protocols into a single protocol
public protocol StateContaining<State>: StateObserving, StatePublishing { }

#endif
