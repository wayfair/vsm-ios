//
//  SettingsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/10/23.
//

import XCTest
@testable import Shopping

final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS" : "YES",
            "RESET_USER_DEFAULTS": "YES"
        ]
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
        app = nil
    }
    
    func testToggleStates() {
        // Tests that each of the toggles work and hold their values between navigations
        MainTestView(app: app)
            .tapAccountsTab()
            .tapSettings()
            .assert(app.switches["Custom Binding Toggle"].value as? String, equals: "0")
            .assert(app.switches["State Binding Toggle"].value as? String, equals: "0")
            .assert(app.switches["Convenience Binding 1 Toggle"].value as? String, equals: "0")
            .assert(app.switches["Convenience Binding 2 Toggle"].value as? String, equals: "0")
            .toggleCustomBinding()
            .toggleStateBinding()
            .toggleConvenienceBinding1()
            .toggleConvenienceBinding2()
            .assert(app.switches["Custom Binding Toggle"].value as? String, equals: "1")
            .assert(app.switches["State Binding Toggle"].value as? String, equals: "1")
            .assert(app.switches["Convenience Binding 1 Toggle"].value as? String, equals: "1")
            .assert(app.switches["Convenience Binding 2 Toggle"].value as? String, equals: "1")
            .tapBackButton()
            .tapSettings()
            .assert(app.switches["Custom Binding Toggle"].value as? String, equals: "1")
            .assert(app.switches["State Binding Toggle"].value as? String, equals: "1")
            .assert(app.switches["Convenience Binding 1 Toggle"].value as? String, equals: "1")
            .assert(app.switches["Convenience Binding 2 Toggle"].value as? String, equals: "1")
    }
}
