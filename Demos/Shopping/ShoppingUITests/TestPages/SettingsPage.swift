//
//  SettingsPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/10/23.
//

import XCTest

/// Test view for the settings toggle switches (custom state bindings)
struct SettingsPage: TestableUI, PushedPage {
    let app: XCUIApplication
    let previousView: AccountTabPage
    
    private var navBarTitle: XCUIElement { app.navigationBars["Settings"] }
    private func toggle(for setting: Setting) -> XCUIElement { app.switches[setting.rawValue] }
    
    
    init(app: XCUIApplication, previousView: AccountTabPage, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        waitFor(navBarTitle, file: file, line: line)
    }
    
    @discardableResult
    func toggleSetting(_ setting: Setting, file: StaticString = #file, line: UInt = #line) -> Self {
        let toggle = toggle(for: setting)
        return find(toggle, hittable: true, enabled: true, file: file, line: line)
            .perform(toggle.tap())
    }
    
    @discardableResult
    func assertSetting(_ setting: Setting, isOn: Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(toggle(for: setting).value as? String, equals: isOn ? "1" : "0", message: "'\(setting.rawValue)' is not \(isOn ? "on" : "off")", file: file, line: line)
    }
    
    enum Setting: String {
        case customBinding = "Custom Binding Toggle"
        case stateBinding = "State Binding Toggle"
        case convenienceBinding1 = "Convenience Binding 1 Toggle"
        case convenienceBinding2 = "Convenience Binding 2 Toggle"
    }
}
