//
//  ProductsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/4/23.
//

import XCTest

class ProductsUITests: UITestCase {
    
    func testProducts() {
        // Tests that each product displays the appropriate information in the list
        mainPage
            .defaultTab()
            .tapProduct("Ottoman")
            .assert(app.navigationBars["Ottoman"].exists)
            .assert(app.staticTexts["$199.99"].exists)
            .assert(app.images["Ottoman Image"].exists)
            .tapBackButton()
            .tapProduct("TV Stand")
            .assert(app.navigationBars["TV Stand"].exists)
            .assert(app.staticTexts["$299.99"].exists)
            .assert(app.images["TV Stand Image"].exists)
            .tapBackButton()
            .tapProduct("Couch")
            .assert(app.navigationBars["Couch"].exists)
            .assert(app.staticTexts["$599.99"].exists)
            .assert(app.images["Couch Image"].exists)
            .tapBackButton()
            .assert(app.navigationBars["Products"].exists)
    }
}
