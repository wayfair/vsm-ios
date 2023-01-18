//
//  CartUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/5/23.
//

import XCTest

class CartUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment = ["UITEST_DISABLE_ANIMATIONS" : "YES"]
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
        app = nil
    }
    
    func testSynchronizedCartState() {
        // Test that adding and removing items from the cart updates the cart button badge
        MainTestView(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
            .tapAddToCart()
            .assert(app.buttons["Adding to Cart..."].exists)
            .assert(app.staticTexts["✅ Added Ottoman to cart."].waitForExistence())
            .assert(app.staticTexts["Cart Item Count"].exists)
            .assert(app.staticTexts["Cart Item Count"].label, equals: "1")
            .assert(app.buttons["Add to Cart"].exists)
            .tapBackButton()
            .tapProduct("TV Stand")
            .tapAddToCart()
            .assert(app.buttons["Adding to Cart..."].exists)
            .assert(app.staticTexts["✅ Added TV Stand to cart."].waitForExistence())
            .assert(app.staticTexts["Cart Item Count"].label, equals: "2")
            .assert(app.buttons["Add to Cart"].exists)
            .tapCartButton()
            .remove("Ottoman")
            .tapCloseButton()
            .assert(app.staticTexts["Cart Item Count"].label, equals: "1")
            .tapCartButton()
            .remove("TV Stand")
            .tapCloseButton()
            .assert(!app.staticTexts["Cart Item Count"].waitForExistence(timeout: 0.1))
    }
    
    func testAddAndRemoveFromCart() {
        // Test that adding and removing products from the cart in the Products view works as expected
        MainTestView(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
            .tapAddToCart()
            .tapBackButton()
            .tapProduct("TV Stand")
            .tapAddToCart()
            .tapBackButton()
            .tapProduct("Couch")
            .tapAddToCart()
            .tapBackButton()
            .tapCartButton()
            .assert(app.staticTexts["$1,099.97"].waitForExistence())
            .assert(app.staticTexts["$299.99"].exists)
            .assert(app.staticTexts["$599.99"].exists)
            .assert(app.staticTexts["$199.99"].exists)
            .remove("Ottoman")
            .assert(app.staticTexts["$899.98"].exists)
            .remove("TV Stand")
            .assert(app.staticTexts["$599.99"].exists)
            .remove("Couch")
            .assert(app.staticTexts["$0.00"].exists)
            .assert(app.staticTexts["Your cart is empty."].waitForExistence())
    }
    
    func testOrder() {
        // Test that adding a product to cart and ordering shows the receipt view
        MainTestView(app: app)
            .defaultTab()
            .tapProduct("Ottoman")
            .tapAddToCart()
            .tapCartButton()
            .tapPlaceOrder()
            .assert(app.staticTexts["Receipt"].waitForExistence())
            .assert(app.staticTexts["Ottoman"].exists)
            .assert(app.staticTexts["$199.99"].exists)
            .tapCloseButton()
    }
}
