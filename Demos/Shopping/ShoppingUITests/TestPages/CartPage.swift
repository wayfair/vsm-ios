//
//  CartPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The test view for the cart which provides the ability to remove cart items and checkout
struct CartPage<ParentView: TestableUI>: PresentedPage {
    let app: XCUIApplication
    var parentView: ParentView
    
    init(app: XCUIApplication, parentView: ParentView, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.parentView = parentView
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(), "Cart didn't finish loading", file: file, line: line)
    }
    
    @discardableResult
    func remove(_ name: String, file: StaticString = #file, line: UInt = #line) -> Self {
        let row = app.collectionViews.cells.containing(.staticText, identifier: name).firstMatch
        let deleteButton = app.buttons["Remove \(name)"]
        XCTAssertTrue(row.waitForExistence(), "Can't find '\(name) Row'", file: file, line: line)
        row.swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(), "Can't find 'Remove \(name)'", file: file, line: line)
        deleteButton.tap()
        XCTAssertTrue(app.activityIndicators["Processing..."].waitForNonexistence(), "'Processing...' is stuck", file: file, line: line)
        return self
    }
    
    @discardableResult
    func tapPlaceOrder(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.buttons["Place Order"].waitForExistence(), "Can't find 'Place Order' button", file: file, line: line)
        app.buttons["Place Order"].tap()
        return self
    }
}

/// Provides cart button behavior to any view that shows a cart button in the nav bar
protocol CartButtonProviding: TestableUI { }

extension CartButtonProviding {
    @discardableResult
    func tapCartButton(file: StaticString = #file, line: UInt = #line) -> CartPage<Self> {
        XCTAssertTrue(app.navigationBars.buttons["Show Cart"].exists, file: file, line: line)
        app.navigationBars.buttons["Show Cart"].tap()
        return .init(app: app, parentView: self, file: file, line: line)
    }
}
