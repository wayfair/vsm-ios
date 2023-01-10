//
//  MainUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 12/29/22.
//

import XCTest

class MainViewTests: XCTestCase {
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
    
    func testTabs() {
        // Tests that the products tab is defaulted and that the inter-tab navigation works
        MainTestView(app: app)
            .defaultTab()
            .tapAccountsTab()
            .tapProductsTab()
    }

}

