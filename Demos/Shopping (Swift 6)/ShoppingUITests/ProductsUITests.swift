//
//  ProductsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

@MainActor
class ProductsUITests: XCTestCase {
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

    func testProducts() {
        // Tests that each product displays the appropriate information in the list
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapBackButton()
            .tapProductCell(for: .couch)
            .tapBackButton()
            .assertProductsPageIsVisible()
    }
}
