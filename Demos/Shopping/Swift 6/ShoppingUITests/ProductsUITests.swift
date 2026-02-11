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
            .tapProductCell(for: .ottoman)
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapBackButton()
            .tapProductCell(for: .couch)
            .tapBackButton()
            .assertProductsPageIsVisible()
    }
}
