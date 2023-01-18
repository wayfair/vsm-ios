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
    var name: String
    
    init(app: XCUIApplication, previousView: ProductsTabPage, name: String, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        self.name = name
        XCTAssertTrue(app.navigationBars[name].waitForExistence(), "Can't find \(name) nav bar item", file: file, line: line)
    }
    
    @discardableResult
    func tapFavorite(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.buttons["Favorite Button"].exists, "Can't find 'Favorite Button'", file: file, line: line)
        app.buttons["Favorite Button"].tap()
        return self
    }
    
    @discardableResult
    func tapUnfavorite(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.buttons["Unfavorite Button"].exists, "Can't find 'Unfavorite Button'", file: file, line: line)
        app.buttons["Unfavorite Button"].tap()
        return self
    }
    
    @discardableResult
    func tapAddToCart(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(app.buttons["Add to Cart"].exists, "Can't find 'Add to Cart' button", file: file, line: line)
        app.buttons["Add to Cart"].tap()
        return self
    }
}
