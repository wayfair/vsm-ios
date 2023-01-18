//
//  MainPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// The main root app view which also supplies the tab bar and the default view
struct MainPage: TabbedPage {
    let app: XCUIApplication
    
    @discardableResult
    func defaultTab(file: StaticString = #file, line: UInt = #line) -> ProductsTabPage {
        .init(app: app, file: file, line: line)
    }
}

/// The default tab that shows products
struct ProductsTabPage: TabbedPage, CartButtonProviding {
    let app: XCUIApplication
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        XCTAssertTrue(app.scrollViews.element(boundBy: 0).waitForExistence(), "Can't find Products scroll view", file: file, line: line)
    }
    
    @discardableResult
    func assertProductsPageIsVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.navigationBars["Products"].exists, message: "Can't find 'Products' nav bar", file: file, line: line)
    }
    
    @discardableResult
    func tapProductCell(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> ProductDetailPage {
        XCTAssertTrue(app.buttons[product.name].exists, "Can't find product cell '\(product.name)' button", file: file, line: line)
        app.buttons[product.name].tap()
        return .init(app: app, previousView: self, product: product, file: file, line: line)
    }
}

/// The second tab view that shows account options
struct AccountTabPage: TabbedPage, CartButtonProviding {
    let app: XCUIApplication
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(), "Can't find Account nav bar item", file: file, line: line)
    }
    
    @discardableResult
    func assertAccountPageIsVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        assert(app.navigationBars["Account"].exists, message: "Can't find 'Account' nav bar", file: file, line: line)
    }
    
    @discardableResult
    func tapFavorites(file: StaticString = #file, line: UInt = #line) -> FavoritesPage {
        XCTAssertTrue(app.buttons["Favorites"].exists, "Can't find Favorites button", file: file, line: line)
        app.buttons["Favorites"].tap()
        return .init(app: app, previousView: self, file: file, line: line)
    }
    
    @discardableResult
    func tapSettings(file: StaticString = #file, line: UInt = #line) -> SettingsPage {
        XCTAssertTrue(app.buttons["Settings"].exists, "Can't find Settings button", file: file, line: line)
        app.buttons["Settings"].tap()
        return .init(app: app, previousView: self, file: file, line: line)
    }
}

enum TestProduct: String {
    case couch = "Couch"
    case ottoman = "Ottoman"
    case tvStand = "TV Stand"
    
    var name: String { rawValue }
    
    var price: String {
        switch self {
        case .couch:
            return "$599.99"
        case .ottoman:
            return "$199.99"
        case .tvStand:
            return "$299.99"
        }
    }
}
