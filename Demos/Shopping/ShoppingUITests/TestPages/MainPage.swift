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
    
    private var navBarTitle: XCUIElement { app.navigationBars["Products"] }
    private func button(for product: TestProduct) -> XCUIElement { app.buttons[product.name] }
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        // XCUIApplication doesn't support LazyVGrids yet, so we have to look for the content of a cell to ensure it's finished loading
        waitFor(button(for: .couch), file: file, line: line)
    }
    
    @discardableResult
    func assertProductsPageIsVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        find(navBarTitle, hittable: true, file: file, line: line)
    }
    
    @discardableResult
    func tapProductCell(for product: TestProduct, file: StaticString = #file, line: UInt = #line) -> ProductDetailPage {
        let productButton = button(for: product)
        waitFor(productButton, hittable: true, enabled: true, file: file, line: line)
            .perform(productButton.tap())
        return .init(app: app, previousView: self, product: product, file: file, line: line)
    }
}

/// The second tab view that shows account options
struct AccountTabPage: TabbedPage, CartButtonProviding {
    let app: XCUIApplication
    
    private var navBarTitle: XCUIElement { app.navigationBars["Account"] }
    private var favoritesButton: XCUIElement { app.buttons["Favorites"] }
    private var settingsButton: XCUIElement { app.buttons["Settings"] }
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        find(navBarTitle, file: file, line: line)
    }
    
    @discardableResult
    func assertAccountPageIsVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        find(navBarTitle, hittable: true, file: file, line: line)
    }
    
    @discardableResult
    func tapFavorites(file: StaticString = #file, line: UInt = #line) -> FavoritesPage {
        find(favoritesButton, hittable: true, enabled: true, file: file, line: line)
            .perform(favoritesButton.tap())
        return .init(app: app, previousView: self, file: file, line: line)
    }
    
    @discardableResult
    func tapSettings(file: StaticString = #file, line: UInt = #line) -> SettingsPage {
        find(settingsButton, hittable: true, enabled: true, file: file, line: line)
            .perform(settingsButton.tap())
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
