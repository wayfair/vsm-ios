//
//  LazyHostedStateDemoApp.swift
//  LazyHostedStateDemo
//

import SwiftUI

@main
struct LazyHostedStateDemoApp: App {
    init() {
        if LaunchConfig.current.isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
