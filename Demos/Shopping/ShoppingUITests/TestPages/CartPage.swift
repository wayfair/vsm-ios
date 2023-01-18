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
    func assertEmptyCart(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.staticTexts["Your cart is empty."].waitForExistence(), message: "Cart is not empty", file: file, line: line)
    }
    
    @discardableResult
    func assertReceiptExists(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.staticTexts["Receipt"].waitForExistence(), message: "Can't find 'Receipt' view", file: file, line: line)
    }
    
    @discardableResult
    func assertTotal(price: String, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.staticTexts["Total: \(price)"].waitForExistence(), message: "Can't find 'Total: \(price)' text", file: file, line: line)
    }
    
    @discardableResult
    func assertInsufficientFunds(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.staticTexts["Insufficient funds!"].waitForExistence(), message: "Can't find 'Insufficient funds!'", file: file, line: line)
    }
    
    @discardableResult
    func assertRowExists(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        let row = app.collectionViews.cells.containing(.staticText, identifier: product.name).firstMatch
        return assert(row.waitForExistence(), message: "Can't find row with '\(product.name)' text", file: file, line: line)
            .assert(row.staticTexts[product.price].exists, message: "Can't find '\(product.price)' text in row", file: file, line: line)
    }
        
    @discardableResult
    func removeRow(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        let row = app.collectionViews.cells.containing(.staticText, identifier: product.name).firstMatch
        let deleteButton = app.buttons["Remove \(product.name)"]
        XCTAssertTrue(row.waitForExistence(), "Can't find '\(product.name) Row'", file: file, line: line)
        row.swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(), "Can't find 'Remove \(product.name)'", file: file, line: line)
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
    func assertCartButtonCount(is count: Int, file: StaticString = #file, line: UInt = #line) -> Self {
        guard count != 0 else {
            return assert(app.staticTexts["Cart Item Count"].waitForNonexistence(), message: "'Cart Item Count' is not empty.", file: file, line: line)
        }
        assert(app.staticTexts["Cart Item Count"].exists, message: "Can't find 'Cart Item Count'", file: file, line: line)
        return assert(app.staticTexts["Cart Item Count"].label, equals: "\(count)", message: "Incorrect cart item count: \(count)", file: file, line: line)
    }
    
    @discardableResult
    func tapCartButton(file: StaticString = #file, line: UInt = #line) -> CartPage<Self> {
        XCTAssertTrue(app.navigationBars.buttons["Show Cart"].exists, file: file, line: line)
        app.navigationBars.buttons["Show Cart"].tap()
        return .init(app: app, parentView: self, file: file, line: line)
    }
}
