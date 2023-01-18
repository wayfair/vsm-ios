//
//  FavoritesPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The test view for the favorites list which provides the ability to remove favorites
struct FavoritesPage: PushedPage, TabbedPage {
    let app: XCUIApplication
    let previousView: AccountTabPage
    
    init(app: XCUIApplication, previousView: AccountTabPage, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        XCTAssertTrue(app.collectionViews.element.waitForExistence(), "Can't find Favorites nav bar item", file: file, line: line)
    }
    
    @discardableResult
    func assertEmptyFavorites(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.staticTexts["You have no favorite products."].waitForExistence(), message: "Favorites is not empty", file: file, line: line)
    }
    
    @discardableResult
    func unfavorite(product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        let row = app.staticTexts["\(product.name) Row"]
        let deleteButton = app.buttons["Delete \(product.name)"]
        XCTAssertTrue(row.waitForExistence(), "Can't find '\(product.name) Row'", file: file, line: line)
        app.staticTexts[product.name].swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(), "Can't find 'Delete \(product.name)'", file: file, line: line)
        deleteButton.tap()
        XCTAssertTrue(app.activityIndicators["Processing..."].waitForNonexistence(), "'Processing...' is stuck", file: file, line: line)
        return self
    }
}
