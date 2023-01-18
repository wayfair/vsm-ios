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
    
    init(app: XCUIApplication, previousView: AccountTabPage, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(), "Can't find Favorites nav bar item", file: file, line: line)
    }
    
    @discardableResult
    func toggleSetting(_ setting: Setting, file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.switches[setting.rawValue].waitForExistence(), "Can't find '\(setting.rawValue)' switch", file: file, line: line)
        app.switches[setting.rawValue].tap()
        return self
    }
    
    @discardableResult
    func assertSetting(_ setting: Setting, isOn: Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.switches[setting.rawValue].value as? String, equals: isOn ? "1" : "0", message: "'\(setting.rawValue)' is not \(isOn ? "on" : "off")", file: file, line: line)
    }
    
    enum Setting: String {
        case customBinding = "Custom Binding Toggle"
        case stateBinding = "State Binding Toggle"
        case convenienceBinding1 = "Convenience Binding 1 Toggle"
        case convenienceBinding2 = "Convenience Binding 2 Toggle"
    }
}
