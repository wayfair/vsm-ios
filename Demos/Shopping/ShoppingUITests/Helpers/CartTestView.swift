//
//  CartTestView.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// Provides cart button behavior to any view that shows a cart button in the nav bar
protocol CartButtonTestView: TestView { }

extension CartButtonTestView {
    @discardableResult
    func tapCartButton(file: StaticString = #file, line: UInt = #line) -> CartTestView<Self> {
        XCTAssertTrue(app.navigationBars.buttons["Show Cart"].exists, file: file, line: line)
        app.navigationBars.buttons["Show Cart"].tap()
        return .init(app: app, parentView: self, file: file, line: line)
    }
}

/// The test view for the cart which provides the ability to remove cart items and checkout
struct CartTestView<ParentView: TestView>: PresentedTestView {
    let app: XCUIApplication
    var parentView: ParentView
    
    init(app: XCUIApplication, parentView: ParentView, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.parentView = parentView
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(), "Cart didn't finish loading", file: file, line: line)
    }
    
    @discardableResult
    func remove(_ name: String, file: StaticString = #file, line: UInt = #line) -> Self {
        // The following is unconventional because of the flakiness of XCTest's automated UI test framework
        // - Use cell w/ query instead of static text because of intermittent search failures
        // - Swipe multiple times because the first swipe is often missed
        let row = app.collectionViews.cells.containing(.staticText, identifier: name).firstMatch
        let deleteButton = app.buttons["Remove \(name)"]
        XCTAssertTrue(row.waitForExistence(), "Can't find '\(name) Row'", file: file, line: line)
        row.swipeLeft()
        row.swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(), "Can't find 'Remove \(name)'", file: file, line: line)
        deleteButton.tap()
        XCTAssertTrue(app.progressIndicators["Processing..."].waitForNonexistence(), "'Processing...' is stuck", file: file, line: line)
        return self
    }
}
