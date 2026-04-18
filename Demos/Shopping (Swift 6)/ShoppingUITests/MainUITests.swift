//
//  MainUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 12/29/22.
//

import XCTest

@MainActor
final class MainUITests: XCTestCase {
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

    func testTabs() {
        // Tests that the products tab is defaulted and that the inter-tab navigation works
        mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapProductsTab()
    }

}

