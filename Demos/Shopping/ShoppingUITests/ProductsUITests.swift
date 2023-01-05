//
//  ProductsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

class ProductsViewTests: XCTestCase {
    static var app: XCUIApplication!
    var app: XCUIApplication { Self.app }
    
    override class func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    override class func tearDown() {
        super.tearDown()
        app = nil
    }
    
    override func setUp() {
        super.setUp()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }
    
    func testProductGridDisplayed() {
        // Test that the Products view displays a grid of 3 products, each with a button labeled "Ottoman", "TV Stand", and "Couch", respectively
        let ottomanButton = app.buttons["Ottoman"]
        _ = ottomanButton.waitForExistence(timeout: 5)
        XCTAssertTrue(ottomanButton.exists)
        XCTAssertTrue(app.buttons["TV Stand"].exists)
        XCTAssertTrue(app.buttons["Couch"].exists)
        
        // Test that the Products view displays an image for each product
        XCTAssertTrue(app.images["Ottoman Image"].exists)
        XCTAssertTrue(app.images["TV Stand Image"].exists)
        XCTAssertTrue(app.images["Couch Image"].exists)
    }
    
    func testProductViewsDisplayed() {
        // Test that tapping on a product in the Products view displays a product view with a navigation bar title matching the product name, and the correct product price is displayed
        let ottomanButton = app.buttons["Ottoman"]
        ottomanButton.tap()
        
        // This line prevents weird error: ("_TtGC7SwiftUI19UIHosting") is not equal to ("Ottoman")
        _ = app.navigationBars.element.waitForExistence(timeout: 5)
        
        XCTAssertEqual(app.navigationBars.element.identifier, "Ottoman")
        XCTAssertTrue(app.staticTexts["$199.99"].exists)
        XCTAssertTrue(app.images["Ottoman Image"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        let tvStandButton = app.buttons["TV Stand"]
        tvStandButton.tap()
        XCTAssertEqual(app.navigationBars.element.identifier, "TV Stand")
        XCTAssertTrue(app.staticTexts["$299.99"].exists)
        XCTAssertTrue(app.images["TV Stand Image"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        let couchButton = app.buttons["Couch"]
        couchButton.tap()
        XCTAssertEqual(app.navigationBars.element.identifier, "Couch")
        XCTAssertTrue(app.staticTexts["$599.99"].exists)
        XCTAssertTrue(app.images["Couch Image"].exists)
        
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

}
