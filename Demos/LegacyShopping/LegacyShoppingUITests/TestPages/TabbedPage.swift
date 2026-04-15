//
//  TabbedPage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/18/23.
//

import XCTest

/// Provides tab navigation functions to any test view that has a visible tab bar
protocol TabbedPage: TestableUI { }

extension TabbedPage {
    
    @discardableResult
    func tapProductsTab(file: StaticString = #file, line: UInt = #line) -> ProductsTabPage {
        tap("Products", file: file, line: line)
        return .init(app: app, file: file, line: line)
    }
    
    @discardableResult
    func tapProductsTab<TabView: TabbedPage>(expectingView: TabView, file: StaticString = #file, line: UInt = #line) -> TabView {
        tap("Products", file: file, line: line)
        return expectingView
    }

    @discardableResult
    func tapAccountsTab(file: StaticString = #file, line: UInt = #line) -> AccountTabPage {
        tap("Account", file: file, line: line)
        return .init(app: app, file: file, line: line)
    }
    
    @discardableResult
    func tapAccountsTab<TabView: TabbedPage>(expectingView: TabView, file: StaticString = #file, line: UInt = #line) -> TabView {
        tap("Account", file: file, line: line)
        return expectingView
    }
    
    func tap(_ tabName: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(app.tabBars.buttons[tabName].exists, "Can't find \(tabName) tab", file: file, line: line)
        app.tabBars.buttons[tabName].tap()
    }
}
