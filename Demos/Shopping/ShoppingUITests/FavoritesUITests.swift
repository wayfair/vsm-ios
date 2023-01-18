//
//  FavoritesUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

class FavoritesUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment = ["UITEST_DISABLE_ANIMATIONS" : "YES"]
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
        app = nil
    }
    
    func testToggleFavoriteButton() {
        // Test that the favorite toggle button toggles and retains its value between navigations
        MainPage(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
            .tapFavorite()
            .tapUnfavorite()
            .tapFavorite()
            .tapBackButton()
            .tapProduct("Ottoman")
            .assert(app.buttons["Unfavorite Button"].exists)
            .tapUnfavorite()
            .assert(app.buttons["Favorite Button"].exists)
            .tapBackButton()
            .tapProduct("Ottoman")
            .assert(app.buttons["Favorite Button"].exists)
    }
    
    func testSynchronizedFavoriteState() {
        // Tests that the favorites state is synchronized between views if changed in one place
        let productView = MainPage(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
        
        productView
            .tapFavorite()
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite("Ottoman")
            .assert(app.staticTexts["You have no favorite products."].waitForExistence())
            .tapProductsTab(expectingView: productView)
            .assert(app.buttons["Favorite Button"].waitForExistence())
    }
    
    func testAddAndRemoveManyFavorites() {
        // Tests that the add/remove many behavior works
        MainPage(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
            .tapFavorite()
            .tapBackButton()
            .tapProduct("TV Stand")
            .tapFavorite()
            .tapBackButton()
            .tapProduct("Couch")
            .tapFavorite()
            .tapAccountsTab()
            .tapFavorites()
            .unfavorite("TV Stand")
            .unfavorite("Ottoman")
            .unfavorite("Couch")
            .assert(app.staticTexts["You have no favorite products."].waitForExistence())
    }
}
