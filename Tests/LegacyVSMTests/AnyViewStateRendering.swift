//
//  AnyViewStateRendering.swift
//  
//
//  Created by Albert Bori on 5/11/22.
//

import SwiftUI
import VSM

/// A concrete test subject for testing various ViewStateRendering extensions
@available(*, deprecated, message: "This type will be removed when ViewStateRendering is removed from the framework")
struct AnyViewStateRendering<ViewState>: ViewStateRendering, View {
    var container: StateContainer<ViewState>
    var body: some View {
        ZStack { }
    }
}
