//
//  CartUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/5/23.
//

import XCTest

class CartUITests: UITestCase {
    
    // MARK: - New Comprehensive Cart Tests
    
    func testAddProductIncrementsBadge() {
        // Test that adding a product to the cart increments the cart badge by 1
        let productsTab = mainPage
            .defaultTab()
        
        // Verify cart starts at 0
        productsTab.assertCartButtonCount(is: 0)
        
        // Navigate to product detail and add to cart
        let productDetailPage = productsTab.tapProductCell(for: .couch)
        
        // Tap the "Add to Cart" button
        let addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        
        // Wait for the add-to-cart operation to complete (2s adding + 2s confirmation + 1s buffer)
        Thread.sleep(forTimeInterval: 5.0)
        
        // Navigate back to products
        productDetailPage.tapBackButton()
        
        // Verify the cart badge shows 1 item
        productsTab.assertCartButtonCount(is: 1)
        
        // Navigate to Cart tab to verify the cart contents
        productsTab
            .tapCartButton()
            .assertRowExists(for: .couch)
    }
    
    func testRemoveSingleItemShowsEmptyCart() {
        // Test that removing the only item from the cart shows the empty cart message
        let productsTab = mainPage
            .defaultTab()
        
        // Navigate to product detail and add to cart
        let productDetailPage = productsTab.tapProductCell(for: .ottoman)
        
        // Tap the "Add to Cart" button
        let addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        
        // Wait for the add-to-cart operation to complete (2s adding + 2s confirmation + 1s buffer)
        Thread.sleep(forTimeInterval: 5.0)
        
        // Navigate back to products
        productDetailPage.tapBackButton()
        
        // Navigate to Cart tab and remove the item
        // The cart will load when we switch to it
        productsTab
            .tapCartButton()
            .assertRowExists(for: .ottoman)
            .removeRow(for: .ottoman)
            .assertEmptyCart()
    }
    
    func testSingleProductCheckout() {
        // Test that adding a single product and checking out shows the receipt
        let productsTab = mainPage
            .defaultTab()
        
        // Navigate to product detail and add to cart
        let productDetailPage = productsTab.tapProductCell(for: .ottoman)
        
        // Tap the "Add to Cart" button
        let addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        
        // Wait for the add-to-cart operation to complete
        Thread.sleep(forTimeInterval: 5.0)
        
        // Navigate back to products
        productDetailPage.tapBackButton()
        
        // Verify the cart badge shows 1 item
        productsTab.assertCartButtonCount(is: 1)
        
        // Navigate to Cart tab, verify item and total, then checkout
        productsTab
            .tapCartButton()
            .assertRowExists(for: .ottoman)
            .assertTotal(price: "$199.99")
            .tapPlaceOrder()
            .assertReceiptExists()
            .assertRowExists(for: .ottoman)
            .assertTotal(price: "$199.99")
    }
    
    func testAddAllThreeProductsShowsInsufficientFunds() {
        // Test that adding all 3 products to the cart and placing order shows insufficient funds error
        let productsTab = mainPage
            .defaultTab()
        
        // Add first product (Couch)
        var productDetailPage = productsTab.tapProductCell(for: .couch)
        var addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        Thread.sleep(forTimeInterval: 5.0)
        productDetailPage.tapBackButton()
        
        // Verify cart badge shows 1
        productsTab.assertCartButtonCount(is: 1)
        
        // Add second product (Ottoman)
        productDetailPage = productsTab.tapProductCell(for: .ottoman)
        addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        Thread.sleep(forTimeInterval: 5.0)
        productDetailPage.tapBackButton()
        
        // Verify cart badge shows 2
        productsTab.assertCartButtonCount(is: 2)
        
        // Add third product (TV Stand)
        productDetailPage = productsTab.tapProductCell(for: .tvStand)
        addToCartButton = app.buttons["Add to Cart"]
        XCTAssertTrue(addToCartButton.waitForExistence(timeout: 5))
        addToCartButton.tap()
        Thread.sleep(forTimeInterval: 5.0)
        productDetailPage.tapBackButton()
        
        // Verify cart badge shows 3
        productsTab.assertCartButtonCount(is: 3)
        
        // Navigate to Cart tab and verify all items, then place order to trigger insufficient funds
        productsTab
            .tapCartButton()
            .assertRowExists(for: .couch)
            .assertRowExists(for: .ottoman)
            .assertRowExists(for: .tvStand)
            .assertTotal(price: "$1,099.97")
            .tapPlaceOrder()
            .assertInsufficientFunds()
    }
}
