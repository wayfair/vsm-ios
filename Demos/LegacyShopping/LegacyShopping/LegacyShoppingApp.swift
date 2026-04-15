//
//  LegacyShoppingApp.swift
//  LegacyShopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import LegacyVSM

@main
struct LegacyShoppingApp: App {
    
    init() {
        // Uncomment this line to see state changes printed to the console for every ViewState in the app.
        // NOTE: The line below will produce a compiler warning in DEBUG, and will break any non-DEBUG build.
        // ViewState._debug()
        
        // Configure for UI testing if necessary
        configureUITestBehavior()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(appDependenciesProvider: AppDependencies.buildProvider())
        }
    }
}

// MARK: Test Support

extension LegacyShoppingApp {
    public static var isUITesting: Bool { CommandLine.arguments.contains("-UITesting") }
    
    func configureUITestBehavior() {
        // Disable animations if running a UI Test
        if Self.isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }
}
