//
//  ProductDetailPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The test view for product detail which provides favorite toggle and add-to-cart behavior
struct ProductDetailPage: PushedPage, TabbedPage, CartButtonProviding {
    var app: XCUIApplication
    var previousView: ProductsTabPage
    var product: TestProduct
    
    init(app: XCUIApplication, previousView: ProductsTabPage, product: TestProduct, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        self.product = product
        assertContentExists(file: file, line: line)
    }
    
    @discardableResult
    func assertContentExists(file: StaticString = #file, line: UInt = #line) -> Self {
        return assert(app.navigationBars[product.name].waitForExistence(), message: "Can't find '\(product.name)' nav bar", file: file, line: line)
            .assert(app.staticTexts[product.price].exists, message: "Can't find price '\(product.price)' text", file: file, line: line)
            .assert(app.images["\(product.name) Image"].exists, message: "Can't find '\(product.name) Image' image", file: file, line: line)
    }
    
    @discardableResult
    func assertFavoriteButtonExists(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.buttons["Favorite Button"].exists, message: "Can't find 'Favorite Button'", file: file, line: line)
    }
    
    @discardableResult
    func assertUnfavoriteButtonExists(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.buttons["Unfavorite Button"].exists, message: "Can't find 'Unfavorite Button'", file: file, line: line)
    }
    
    @discardableResult
    func tapFavoriteButton(file: StaticString = #file, line: UInt = #line) -> Self {
        assertFavoriteButtonExists(file: file, line: line)
        app.buttons["Favorite Button"].tap()
        return assertUnfavoriteButtonExists(file: file, line: line)
    }
    
    @discardableResult
    func tapUnfavoriteButton(file: StaticString = #file, line: UInt = #line) -> Self {
        assertUnfavoriteButtonExists(file: file, line: line)
        app.buttons["Unfavorite Button"].tap()
        return assertFavoriteButtonExists(file: file, line: line)
    }
    
    @discardableResult
    func assertAddToCartButtonExists(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.buttons["Add to Cart"].exists, message: "Can't find 'Add to Cart' button", file: file, line: line)
    }
    
    @discardableResult
    func tapAddToCartButton(file: StaticString = #file, line: UInt = #line) -> Self {
        assertAddToCartButtonExists(file: file, line: line)
        app.buttons["Add to Cart"].tap()
        return assert(app.buttons["Adding to Cart..."].exists, message: "Can't find 'Adding to Cart...' progress indicator", file: file, line: line)
            .assert(app.staticTexts["✅ Added \(product.name) to cart."].waitForExistence(), message: "Can't find '✅ Added \(product.name) to cart.' confirmation text", file: file, line: line)
            .assertAddToCartButtonExists(file: file, line: line)
    }
}
