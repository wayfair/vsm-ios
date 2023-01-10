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
        
        // Disable animations if running a UI Test
        if ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "YES" {
            UIView.setAnimationsEnabled(false)
        }
        
        // Reset user defaults if running a UI Test
        if ProcessInfo.processInfo.environment["RESET_USER_DEFAULTS"] == "YES" {
            UserDefaults.standard.set(false, forKey: SettingsViewStateModel.SettingKey.isCustomBindingExampleEnabled)
            UserDefaults.standard.set(false, forKey: SettingsViewStateModel.SettingKey.isStateBindingExampleEnabled)
            UserDefaults.standard.set(false, forKey: SettingsViewStateModel.SettingKey.isConvenienceBindingExampleEnabled1)
            UserDefaults.standard.set(false, forKey: SettingsViewStateModel.SettingKey.isConvenienceBindingExampleEnabled2)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(appDependenciesProvider: AppDependencies.buildProvider())
        }
    }
}
