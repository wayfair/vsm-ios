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
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
    }

    func testTabs() {
        // Test that the default tab index is 0 and the ProductsView is displayed
        XCTAssertTrue(app.navigationBars["Products"].exists)
        
        // Test that tapping the AccountView tab changes the selected tab and displays the AccountView
        let accountTab = app.tabBars.buttons["Account"]
        accountTab.tap()
        XCTAssertTrue(app.navigationBars["Account"].exists)
        
        // Test that switching to the Products tab displays the ProductsView
        let productsTab = app.tabBars.buttons["Products"]
        productsTab.tap()
        XCTAssertTrue(app.navigationBars["Products"].exists)
    }

}

