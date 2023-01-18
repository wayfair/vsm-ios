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
    func toggleCustomBinding(file: StaticString = #file, line: UInt = #line) -> Self {
        toggle("Custom Binding Toggle")
    }
    
    @discardableResult
    func toggleStateBinding(file: StaticString = #file, line: UInt = #line) -> Self {
        toggle("State Binding Toggle")
    }
    
    @discardableResult
    func toggleConvenienceBinding1(file: StaticString = #file, line: UInt = #line) -> Self {
        toggle("Convenience Binding 1 Toggle")
    }
    
    @discardableResult
    func toggleConvenienceBinding2(file: StaticString = #file, line: UInt = #line) -> Self {
        toggle("Convenience Binding 2 Toggle")
    }
    
    private func toggle(_ switchName: String, file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.switches[switchName].waitForExistence(), "Can't find '\(switchName)' switch", file: file, line: line)
        app.switches[switchName].tap()
        return self
    }
}
