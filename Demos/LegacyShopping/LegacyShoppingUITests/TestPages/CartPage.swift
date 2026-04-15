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
    
    private var emptyCartMessage: XCUIElement { app.staticTexts["Your cart is empty."] }
    private var receiptTitle: XCUIElement { app.staticTexts["Receipt"] }
    private func totalLabel(price: String) -> XCUIElement { app.staticTexts["Total: \(price)"] }
    private var insufficientFunds: XCUIElement { app.staticTexts["Insufficient funds!"] }
    private func row(for product: TestProduct) -> XCUIElement { app.collectionViews.cells.containing(.staticText, identifier: product.name).firstMatch }
    private func price(for product: TestProduct) -> XCUIElement { row(for: product).staticTexts[product.price] }
    private func deleteButton(for product: TestProduct) -> XCUIElement { app.buttons["Remove \(product.name)"] }
    private var placeOrderButton: XCUIElement { app.buttons["Place Order"] }
    private var processingIndicator: XCUIElement { app.activityIndicators["Processing..."] }
    
    init(app: XCUIApplication, parentView: ParentView, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.parentView = parentView
        waitFor(app.collectionViews.firstMatch, file: file, line: line)
    }
    
    @discardableResult
    func assertEmptyCart(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(emptyCartMessage, file: file, line: line)
    }
    
    @discardableResult
    func assertReceiptExists(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(receiptTitle, file: file, line: line)
    }
    
    @discardableResult
    func assertTotal(price: String, file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(totalLabel(price: price), file: file, line: line)
    }
    
    @discardableResult
    func assertInsufficientFunds(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(insufficientFunds, file: file, line: line)
    }
    
    @discardableResult
    func assertRowExists(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(row(for: product), message: "Can't find row containing '\(product.name)'", file: file, line: line)
            .find(price(for: product), file: file, line: line)
    }
        
    @discardableResult
    func removeRow(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        let productRow = row(for: product)
        let deleteButton = deleteButton(for: product)
        return waitFor(productRow, hittable: true, enabled: true, message: "Can't find row containing '\(product.name)'", file: file, line: line)
            .perform(productRow.swipeLeft())
            .find(deleteButton, hittable: true, enabled: true, file: file, line: line)
            .perform(deleteButton.tap())
            .find(processingIndicator, file: file, line: line)
            .waitForNo(processingIndicator, file: file, line: line)
    }
    
    @discardableResult
    func tapPlaceOrder(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(placeOrderButton, hittable: true, enabled: true, file: file, line: line)
            .perform(placeOrderButton.tap())
    }
}

/// Provides cart button behavior to any view that shows a cart button in the nav bar
protocol CartButtonProviding: TestableUI { }

extension CartButtonProviding {
    
    var showCartButton: XCUIElement { app.navigationBars.buttons["Show Cart"] }
    var countBadge: XCUIElement { app.staticTexts["Cart Item Count"] }
    
    @discardableResult
    func assertCartButtonCount(is count: Int, file: StaticString = #file, line: UInt = #line) -> Self {
        guard count != 0 else {
            return waitForNo(countBadge, file: file, line: line)
        }
        return find(countBadge, file: file, line: line)
            .assert(countBadge.label, equals: "\(count)", message: "Incorrect cart item count: \(count)", file: file, line: line)
    }
    
    @discardableResult
    func tapCartButton(file: StaticString = #file, line: UInt = #line) -> CartPage<Self> {
        find(showCartButton, file: file, line: line)
        showCartButton.tap()
        return .init(app: app, parentView: self, file: file, line: line)
    }
}
