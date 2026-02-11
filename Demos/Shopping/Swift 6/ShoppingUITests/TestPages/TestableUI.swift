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
    func assert(_ condition: Bool, message: String? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        if let message {
            XCTAssertTrue(condition, message, file: file, line: line)
        } else {
            XCTAssertTrue(condition, file: file, line: line)
        }
        return self
    }
    
    /// Asserts that the first parameter equals the second while preserving fluent API calls
    @discardableResult
    func assert<Value: Equatable>(_ left: Value, equals right: Value, message: String? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        if let message {
            XCTAssertEqual(left, right, message, file: file, line: line)
        } else {
            XCTAssertEqual(left, right, file: file, line: line)
        }
        return self
    }
    
    /// Executes the assertion statement while preserving fluent API calls
    @discardableResult
    func assert(_ statement: @autoclosure () -> Void, file: StaticString = #file, line: UInt = #line) -> Self {
        statement()
        return self
    }
    
    /// Locates the element ensuring it exists
    /// - Parameters:
    ///   - element: The element to locate
    ///   - hittable: If the element should be hittable to qualify as found
    ///   - enabled: If the element should be enabled to qualify as found
    ///   - file: The file of the caller
    ///   - line: The line of the caller
    /// - Returns: self, if successful
    @discardableResult
    func find(_ element: XCUIElement, hittable: Bool? = nil, enabled: Bool? = nil, message: String? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(element.exists, message: message ?? "Can't find \(element.description)", file: file, line: line)
            .assert(hittable == nil || element.isHittable == hittable, message: message ?? "Can't hit \(element.description)", file: file, line: line)
            .assert(enabled == nil || element.isEnabled == enabled, message: message ?? "\(element.description) isn't enabled", file: file, line: line)
    }
    
    /// Waits the minimum amount of time for an element to come into existence
    /// - Parameters:
    ///   - element: The element to locate
    ///   - hittable: If the element should be hittable to qualify as found
    ///   - enabled: If the element should be enabled to qualify as found
    ///   - timeout: The maximum amount of time to wait (Defaults to 5 seconds)
    ///   - file: The file of the caller
    ///   - line: The line of the caller
    /// - Returns: self, if successful
    @discardableResult
    func waitFor(_ element: XCUIElement, hittable: Bool? = nil, enabled: Bool? = nil, timeout: TimeInterval = 5, message: String? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(element.waitForExistence(hittable: hittable, enabled: enabled, timeout: timeout), message: message ?? "Can't find \(element.description)", file: file, line: line)
    }
    
    /// Waits the minimum amount of time for an element to no longer exist
    /// - Parameters:
    ///   - element: The element to locate
    ///   - file: The file of the caller
    ///   - line: The line of the caller
    /// - Returns: self, if successful
    @discardableResult
    func waitForNo(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) -> Self {
        assert(element.waitForNonexistence(timeout: timeout), message: "\(element.description) still exists", file: file, line: line)
    }
    
    /// Allows functions to be called without breaking fluent API chains. Does nothing with the result.
    @discardableResult
    func perform<IgnoredResult>(_ result: IgnoredResult) -> Self {
        self
    }
}

/// Provides back button navigation to test views that are pushed onto the navigation stack
protocol PushedPage<PreviousPage>: TestableUI {
    associatedtype PreviousPage: TestableUI
    var previousView: PreviousPage { get }
}

extension PushedPage {
    
    var backButton: XCUIElement { app.navigationBars.buttons.element(boundBy: 0) }
    
    @discardableResult
    func tapBackButton(file: StaticString = #file, line: UInt = #line) -> PreviousPage {
        find(backButton, hittable: true, enabled: true, file: file, line: line)
            .perform(backButton.tap())
        return previousView
    }
}

/// Provides back-button navigation to test views that are presented from another view controller
protocol PresentedPage<ParentPage>: TestableUI {
    associatedtype ParentPage: TestableUI
    var parentView: ParentPage { get }
}

extension PresentedPage {
    
    var closeButton: XCUIElement { app.buttons["Close"] }
    
    @discardableResult
    func tapCloseButton(file: StaticString = #file, line: UInt = #line) -> ParentPage {
        find(closeButton, hittable: true, enabled: true, file: file, line: line)
            .perform(closeButton.tap())
        return parentView
    }
}
