//
//  FavoritesUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

class FavoritesUITests: XCTestCase {
    static var app: XCUIApplication!
    var app: XCUIApplication { Self.app }
    
    override class func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    override class func tearDown() {
        super.tearDown()
        app = nil
    }
    
    override func setUp() {
        super.setUp()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }
    
    func testOttomanFavoriteButton() {
        // Test that tapping the "Ottoman" button in the Products view displays the Ottoman product view, and that tapping the "Favorite Button" changes it to the "Unfavorite Button" and tapping the "Unfavorite Button" changes it to the "Favorite Button"
        app.buttons["Ottoman"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))
        let favoriteButton = app.buttons["Favorite Button"]
        XCTAssertTrue(favoriteButton.exists)
        favoriteButton.tap()
        XCTAssertFalse(favoriteButton.exists)
        XCTAssertTrue(app.buttons["Unfavorite Button"].exists)
        app.buttons["Unfavorite Button"].tap()
        XCTAssertTrue(favoriteButton.exists)
        XCTAssertFalse(app.buttons["Unfavorite Button"].exists)
    }
    
    func testSynchronizedFavorites() {
        // Test that tapping the "Ottoman" button in the Products view displays the Ottoman product view, then adding the Ottoman to favorites, then deleting the Ottoman from favorites, then adding it back to favorites
        app.buttons["Ottoman"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))
        app.buttons["Favorite Button"].tap()
        app.tabBars.buttons["Account"].tap()
        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Ottoman"].exists)
        app.staticTexts["Ottoman"].swipeLeft()
        app.buttons["Delete Ottoman"].tap()
        XCTAssertTrue(app.staticTexts["You have no favorite products."].waitForExistence(timeout: 5))
        app.tabBars.buttons["Products"].tap()
        XCTAssertTrue(app.buttons["Favorite Button"].exists)
        app.buttons["Favorite Button"].tap()
        app.tabBars.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Ottoman"].exists)
    }
    
    func testAddAndRemoveFavorites() {
        // Test that adding and removing products from the favorites list in the Products view works as expected
        app.tabBars.buttons["Products"].tap()

        app.buttons["Ottoman"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
        app.buttons["Favorite Button"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["TV Stand"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
        app.buttons["Favorite Button"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Couch"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
        app.buttons["Favorite Button"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Account"].tap()
        app.buttons["Favorites"].tap()
        
        app.staticTexts["Ottoman Row"].swipeLeft()
        app.buttons["Delete Ottoman"].tap()
        
        XCTAssertTrue(app.staticTexts["TV Stand Row"].waitForExistence(timeout: 3))
        app.staticTexts["TV Stand Row"].swipeLeft()
        app.buttons["Delete TV Stand"].tap()
        
        
        XCTAssertTrue(app.staticTexts["Couch Row"].waitForExistence(timeout: 3))
        app.staticTexts["Couch Row"].swipeLeft()
        app.buttons["Delete Couch"].tap()
                
        XCTAssertTrue(app.staticTexts["You have no favorite products."].waitForExistence(timeout: 3))
    }
}
