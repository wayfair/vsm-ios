//
//  FavoritesUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

@MainActor
final class FavoritesUITests: XCTestCase {
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

    func testToggleFavoriteButton() {
        // Test that the favorite toggle button toggles and retains its value between navigations
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapFavoriteButton()
            .tapUnfavoriteButton()
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .ottoman)
            .tapUnfavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .ottoman)
            .assertProduct(isFavorited: false)
    }
    
    func testSynchronizedFavoriteState() {
        // Tests that the favorites state is synchronized between views if changed in one place
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapFavoriteButton()
            .tapBackButton()
        
        // Navigate to favorites and unfavorite
        mainPage
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite(product: .ottoman)
            .assertEmptyFavorites()
            .tapProductsTab()
            .tapProductCell(for: .ottoman)
            .assertProduct(isFavorited: false)
    }
    
    func testAddAndRemoveManyFavorites() {
        // Tests that the add/remove many behavior works
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapFavoriteButton()
            .tapBackButton()
            .tapProductCell(for: .couch)
            .tapFavoriteButton()
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite(product: .tvStand)
            .unfavorite(product: .ottoman)
            .unfavorite(product: .couch)
            .assertEmptyFavorites()
    }
}
