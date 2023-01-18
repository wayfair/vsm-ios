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
    func unfavorite(_ name: String, file: StaticString = #file, line: UInt = #line) -> Self {
        let row = app.staticTexts["\(name) Row"]
        let deleteButton = app.buttons["Delete \(name)"]
        XCTAssertTrue(row.waitForExistence(), "Can't find '\(name) Row'", file: file, line: line)
        app.staticTexts[name].swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(), "Can't find 'Delete \(name)'", file: file, line: line)
        deleteButton.tap()
        XCTAssertTrue(app.activityIndicators["Processing..."].waitForNonexistence(), "'Processing...' is stuck", file: file, line: line)
        return self
    }
}
