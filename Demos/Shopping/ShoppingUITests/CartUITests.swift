//
//  CartUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/5/23.
//

import XCTest

class CartUITests: UITestCase {
    
    func testSynchronizedCartState() {
        // Test that adding and removing items from the cart updates the cart button badge
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapAddToCartButton()
            .assertCartButtonCount(is: 1)
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapAddToCartButton()
            .assertCartButtonCount(is: 2)
            .tapCartButton()
            .removeRow(for: .ottoman)
            .tapCloseButton()
            .assertCartButtonCount(is: 1)
            .tapCartButton()
            .removeRow(for: .tvStand)
            .tapCloseButton()
            .assertCartButtonCount(is: 0)
    }
    
    func testAddAndRemoveFromCart() {
        // Test that adding and removing products from the cart in the Products view works as expected
        mainPage
            .defaultTab()
            .tapProductCell(for: .ottoman)
            .tapAddToCartButton()
            .tapBackButton()
            .tapProductCell(for: .tvStand)
            .tapAddToCartButton()
            .tapBackButton()
            .tapProductCell(for: .couch)
            .tapAddToCartButton()
            .tapBackButton()
            .tapCartButton()
            .assertTotal(price: "$1,099.97")
            .assertRowExists(for: .couch)
            .assertRowExists(for: .ottoman)
            .assertRowExists(for: .tvStand)
            .removeRow(for: .ottoman)
            .assertTotal(price: "$899.98")
            .removeRow(for: .tvStand)
            .assertTotal(price: "$599.99")
            .removeRow(for: .couch)
            .assertTotal(price: "$0.00")
            .assertEmptyCart()
    }
    
    func testSingleItemOrder() {
        // Test that adding a product to cart and ordering shows the receipt view
        mainPage
            .defaultTab()
            .tapProductCell(for: .couch)
            .tapAddToCartButton()
            .tapCartButton()
            .assertRowExists(for: .couch)
            .assertTotal(price: "$599.99")
            .tapPlaceOrder()
            .assertReceiptExists()
            .assertRowExists(for: .couch)
            .assertTotal(price: "$599.99")
            .tapCloseButton()
            .assertProductDetailPageIsVisible()
    }
    
    func testInsufficientFunds() {
        // Test that adding too many products to the cart and ordering shows insufficient funds error
        mainPage
            .defaultTab()
            .tapProductCell(for: .couch)
            .tapAddToCartButton()
            .tapBackButton()
            .tapProductCell(for: .ottoman)
            .tapAddToCartButton()
            .tapCartButton()
            .assertRowExists(for: .couch)
            .assertRowExists(for: .ottoman)
            .tapPlaceOrder()
            .assertInsufficientFunds()
            .removeRow(for: .couch)
            .tapPlaceOrder()
            .assertReceiptExists()
            .assertTotal(price: "$199.99")
            .tapCloseButton()
            .assertProductDetailPageIsVisible()
    }
}
