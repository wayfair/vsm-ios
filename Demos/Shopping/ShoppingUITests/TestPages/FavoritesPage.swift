//
//  FavoritesPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The test view for the favorites list which provides the ability to remove favorites
struct FavoritesPage: PushedPage, TabbedPage {
    let app: XCUIApplication
    let previousView: AccountTabPage
    
    private var firstCollectionViewElement: XCUIElement { app.collectionViews.element }
    private var emptyListLabel: XCUIElement { app.staticTexts["You have no favorite products."] }
    private func rowLabel(for product: TestProduct) -> XCUIElement { app.staticTexts["\(product.name) Row"] }
    private func deleteButton(for product: TestProduct) -> XCUIElement { app.buttons["Delete \(product.name)"] }
    private var processingIndicator: XCUIElement { app.activityIndicators["Processing..."] }
    
    init(app: XCUIApplication, previousView: AccountTabPage, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        waitFor(firstCollectionViewElement, message: "Favorites didn't finish loading", file: file, line: line)
    }
    
    @discardableResult
    func assertEmptyFavorites(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(emptyListLabel, file: file, line: line)
    }
    
    @discardableResult
    func unfavorite(product: TestProduct, file: StaticString = #file, line: UInt = #line) -> Self {
        let productLabel = rowLabel(for: product)
        let deleteButton = deleteButton(for: product)
        return find(productLabel, hittable: true, enabled: true, file: file, line: line)
            .perform(productLabel.swipeLeft())
            .find(deleteButton, hittable: true, enabled: true, file: file, line: line)
            .perform(deleteButton.tap())
            .waitForNo(processingIndicator, file: file, line: line)
    }
}
