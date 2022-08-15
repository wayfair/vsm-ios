//
//  ShoppingApp.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import SwiftUI
import VSM

@main
struct ShoppingApp: App {
    init() {
        // Uncomment this line to see state changes printed to the console for every StateContainer in the app.
        // NOTE: The line below will produce a compiler warning in DEBUG, and will break any non-DEBUG build.
        // StateContainer.debug()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(appDependenciesProvider: AppDependencies.buildProvider())
        }
    }
}
