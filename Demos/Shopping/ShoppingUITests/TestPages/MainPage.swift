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
    func tapProduct(_ name: String, file: StaticString = #file, line: UInt = #line) -> ProductDetailPage {
        XCTAssertTrue(app.buttons[name].exists, file: file, line: line)
        app.buttons[name].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(), file: file, line: line)
        return .init(app: app, previousView: self, name: name, file: file, line: line)
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
