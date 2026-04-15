//
//  ProductDetailPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The test view for product detail which provides favorite toggle and add-to-cart behavior
@MainActor
struct ProductDetailPage: PushedPage, TabbedPage, CartButtonProviding {
    var app: XCUIApplication
    var previousView: ProductsTabPage
    var product: TestProduct
    
    private var navigationBar: XCUIElement { app.navigationBars[product.name] }
    private var productPrice: XCUIElement { app.staticTexts[product.price] }
    private var productImage: XCUIElement { app.images["\(product.name) Image"] }
    private var favoriteButton: XCUIElement { app.buttons["Favorite Button"] }
    private var unfavoriteButton: XCUIElement { app.buttons["Unfavorite Button"] }
    private var inactiveFavoriteButton: XCUIElement { app.buttons["Inactive Favorite Button"] }
    private var addToCartButton: XCUIElement { app.buttons["Add to Cart"] }
    private var addingToCartButton: XCUIElement { app.buttons["Adding to Cart..."] }
    private var addToCartConfirmation: XCUIElement { app.staticTexts["✅ Added \(product.name) to cart."] }
    
    init(app: XCUIApplication, previousView: ProductsTabPage, product: TestProduct, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        self.product = product
        assertProductDetailPageIsVisible(file: file, line: line)
    }
    
    @discardableResult
    func assertProductDetailPageIsVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(navigationBar, file: file, line: line)
            .find(productPrice, file: file, line: line)
            .find(productImage, file: file, line: line)
    }
    
    @discardableResult
    func assertProduct(isFavorited: Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        // Wait for the inactive button to disappear (button loading complete)
        // The button starts as "Inactive Favorite Button" while loading, then becomes either
        // "Favorite Button" or "Unfavorite Button" once loaded
        if inactiveFavoriteButton.exists {
            waitForNo(inactiveFavoriteButton, timeout: 10, file: file, line: line)
        }
        
        // Now verify the correct button state
        if isFavorited {
            waitFor(unfavoriteButton, enabled: true, timeout: 10, file: file, line: line)
        } else {
            waitFor(favoriteButton, enabled: true, timeout: 10, file: file, line: line)
        }
        return self
    }
    
    @discardableResult
    func tapFavoriteButton(file: StaticString = #file, line: UInt = #line) -> Self {
        // Wait for the favorite button to finish loading and become enabled
        waitFor(favoriteButton, hittable: true, enabled: true, file: file, line: line)
            .perform(favoriteButton.tap())
            .waitFor(unfavoriteButton, file: file, line: line)
    }
    
    @discardableResult
    func tapUnfavoriteButton(file: StaticString = #file, line: UInt = #line) -> Self {
        // Wait for the unfavorite button to finish loading and become enabled
        waitFor(unfavoriteButton, hittable: true, enabled: true, file: file, line: line)
            .perform(unfavoriteButton.tap())
            .waitFor(favoriteButton, file: file, line: line)
    }
}
