//
//  ProfileUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/26/23.
//

import XCTest

@MainActor
final class ProfileUITests: XCTestCase {
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

    func testUsernameEditing() {
        /// Checks that the error and saving states correctly show, and that the value is persistent after navigating away
        let profilePage = mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapProfile()
        
        // Wait for the profile to load and verify initial state
        profilePage.waitForInitialLoad()
        
        profilePage
            .clearUsernameField()
            .assert(username: "User Name")
            .assertNoSavingIndicator()
            .assertErrorMessage()
            .type(username: "FooBar")
            .assertSavingIndicator()
            .assertNoErrorMessage()
            .tapBackButton()
            .tapProfile()
            .waitForInitialLoad()
            .assert(username: "FooBar")
    }
}
