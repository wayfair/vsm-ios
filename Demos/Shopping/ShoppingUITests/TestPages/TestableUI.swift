//
//  TestableUI.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/6/23.
//

import XCTest

/// A generic view tester type used for automated UI tests of the Shopping demo app
protocol TestableUI {
    var app: XCUIApplication { get }
}

extension TestableUI {
    /// Asserts that the condition is true while preserving fluent API calls
    @discardableResult
    func assert(_ condition: Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertTrue(condition, file: file, line: line)
        return self
    }
    
    /// Asserts that the first parameter equals the second while preserving fluent API calls
    @discardableResult
    func assert<Value: Equatable>(_ left: Value, equals right: Value, file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssertEqual(left, right, file: file, line: line)
        return self
    }
    
    /// Executes the assertion statement while preserving fluent API calls
    @discardableResult
    func assert(_ statement: () -> Void, file: StaticString = #file, line: UInt = #line) -> Self {
        statement()
        return self
    }
}

/// Provides back button navigation to test views that are pushed onto the navigation stack
protocol PushedPage<PreviousPage>: TestableUI {
    associatedtype PreviousPage: TestableUI
    var previousView: PreviousPage { get }
}

extension PushedPage {
    @discardableResult
    func tapBackButton() -> PreviousPage {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        return previousView
    }
}

/// Provides back-button navigation to test views that are presented from another view controller
protocol PresentedPage<ParentPage>: TestableUI {
    associatedtype ParentPage: TestableUI
    var parentView: ParentPage { get }
}

extension PresentedPage {
    @discardableResult
    func tapCloseButton() -> ParentPage {
        app.buttons["Close"].tap()
        return parentView
    }
}
