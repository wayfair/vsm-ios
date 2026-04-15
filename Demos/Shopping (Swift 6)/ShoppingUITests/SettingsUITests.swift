//
//  SettingsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/10/23.
//

import XCTest
@testable import Shopping

@MainActor
final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!
    var mainPage: MainPage { MainPage(app: app) }

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false

        await MainActor.run {
            app = XCUIApplication()
            app.launchArguments += ["-UITesting"]

            let frameworkArgs: Set<String> = ["-ui-framework", "uikit"]
            app.launchArguments += ProcessInfo.processInfo.arguments.filter({ frameworkArgs.contains($0) })
            app.launch()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            app = nil
        }
        try await super.tearDown()
    }

    func testToggleStates() {
        // Tests that each of the toggles work and hold their values between navigations
        mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapSettings()
            .assertSetting(.convenienceBinding1, isOn: false)
            .assertSetting(.convenienceBinding2, isOn: false)
            .assertSetting(.customBinding, isOn: false)
            .assertSetting(.stateBinding, isOn: false)
            .toggleSetting(.convenienceBinding1)
            .toggleSetting(.convenienceBinding2)
            .toggleSetting(.customBinding)
            .toggleSetting(.stateBinding)
            .assertSetting(.convenienceBinding1, isOn: true)
            .assertSetting(.convenienceBinding2, isOn: true)
            .assertSetting(.customBinding, isOn: true)
            .assertSetting(.stateBinding, isOn: true)
            .tapBackButton()
            .tapSettings()
            .assertSetting(.convenienceBinding1, isOn: true)
            .assertSetting(.convenienceBinding2, isOn: true)
            .assertSetting(.customBinding, isOn: true)
            .assertSetting(.stateBinding, isOn: true)
    }
}
