//
//  MainUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 12/29/22.
//

import XCTest

class MainUITests: UITestCase {
    
    func testTabs() {
        // Tests that the products tab is defaulted and that the inter-tab navigation works
        mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapProductsTab()
    }

}

