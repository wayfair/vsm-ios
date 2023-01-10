//
//  MainTabTestView.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// Provides tab navigation functions to any test view that has a visible tab bar
protocol TabTestView: TestView { }

extension TabTestView {
    
    @discardableResult
    func tapProductsTab(file: StaticString = #file, line: UInt = #line) -> ProductsTabTestView {
        tap("Products", file: file, line: line)
        return .init(app: app, file: file, line: line)
    }
    
    @discardableResult
    func tapProductsTab<TabView: TabTestView>(expectingView: TabView, file: StaticString = #file, line: UInt = #line) -> TabView {
        tap("Products", file: file, line: line)
        return expectingView
    }

    @discardableResult
    func tapAccountsTab(file: StaticString = #file, line: UInt = #line) -> AccountTabTestView {
        tap("Account", file: file, line: line)
        return .init(app: app, file: file, line: line)
    }
    
    @discardableResult
    func tapAccountsTab<TabView: TabTestView>(expectingView: TabView, file: StaticString = #file, line: UInt = #line) -> TabView {
        tap("Account", file: file, line: line)
        return expectingView
    }
    
    func tap(_ tabName: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(app.tabBars.buttons[tabName].exists, "Can't find \(tabName) tab", file: file, line: line)
        app.tabBars.buttons[tabName].tap()
    }
}

/// The main root app view which also supplies the tab bar and the default view
struct MainTestView: TabTestView {
    let app: XCUIApplication
    
    @discardableResult
    func defaultTab(file: StaticString = #file, line: UInt = #line) -> ProductsTabTestView {
        .init(app: app, file: file, line: line)
    }
}

/// The default tab that shows products
struct ProductsTabTestView: TabTestView, CartButtonTestView {
    let app: XCUIApplication
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        XCTAssertTrue(app.scrollViews.element(boundBy: 0).waitForExistence(), "Can't find Products scroll view", file: file, line: line)
    }
    
    @discardableResult
    func tapProduct(_ name: String, file: StaticString = #file, line: UInt = #line) -> ProductDetailTestView {
        XCTAssertTrue(app.buttons[name].exists, file: file, line: line)
        app.buttons[name].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(), file: file, line: line)
        return .init(app: app, previousView: self, name: name, file: file, line: line)
    }
}

/// The second tab view that shows account options
struct AccountTabTestView: TabTestView, CartButtonTestView {
    let app: XCUIApplication
    
    init(app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(), "Can't find Account nav bar item", file: file, line: line)
    }
    
    @discardableResult
    func tapFavorites(file: StaticString = #file, line: UInt = #line) -> FavoritesTestView {
        XCTAssertTrue(app.buttons["Favorites"].exists, "Can't find Favorites button", file: file, line: line)
        app.buttons["Favorites"].tap()
        return .init(app: app, previousView: self, file: file, line: line)
    }
}
