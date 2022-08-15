//
//  AnyViewStateRendering.swift
//  
//
//  Created by Albert Bori on 5/11/22.
//

import SwiftUI
import VSM

/// A concrete test subject for testing various ViewStateRendering extensions
struct AnyViewStateRendering<ViewState>: ViewStateRendering, View {
    var container: StateContainer<ViewState>
    var body: some View {
        ZStack { }
    }
}
