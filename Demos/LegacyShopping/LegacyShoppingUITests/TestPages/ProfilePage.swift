//
//  ProfilePage.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/26/23.
//

import XCTest


/// Test view for the profile editor view
struct ProfilePage: TestableUI, PushedPage {
    let app: XCUIApplication
    let previousView: AccountTabPage
    
    private var navigationBar: XCUIElement { app.navigationBars["Profile"] }
    private var loadingIndicator: XCUIElement { app.activityIndicators["Loading..."] }
    private var usernameTextField: XCUIElement { app.textFields["User Name"] }
    private var savingIndicator: XCUIElement { app.activityIndicators["Saving..."] }
    private var errorMessage: XCUIElement { app.staticTexts["Username must not be empty."] }
    
    init(app: XCUIApplication, previousView: AccountTabPage, file: StaticString = #file, line: UInt = #line) {
        self.app = app
        self.previousView = previousView
        find(navigationBar, file: file, line: line)
        if !usernameTextField.exists {
            waitFor(loadingIndicator, file: file, line: line)
        }
        waitFor(usernameTextField, file: file, line: line)
    }
    
    @discardableResult
    func clearUsernameField(file: StaticString = #file, line: UInt = #line) -> Self {
        let text = getUsernameValue(file: file, line: line)
        guard !text.isEmpty else {
            XCTFail("Username text field already cleared")
            return self
        }
        usernameTextField.doubleTap()
        usernameTextField.typeText(XCUIKeyboardKey.delete.rawValue)
        return self
    }
    
    @discardableResult
    func type(username: String, file: StaticString = #file, line: UInt = #line) -> Self {
        selectUsernameField()
        usernameTextField.typeText(username)
        return self
    }
    
    @discardableResult
    func assert(username: String, file: StaticString = #file, line: UInt = #line) -> Self {
        let text = getUsernameValue(file: file, line: line)
        XCTAssert(text == username, "Username text field value '\(text)' not equal to '\(username)'", file: file, line: line)
        return self
    }
    
    private func selectUsernameField() {
        if !usernameTextField.isSelected {
            usernameTextField.tap()
        }
    }
    
    private func getUsernameValue(file: StaticString = #file, line: UInt = #line) -> String {
        guard let text = usernameTextField.value as? String else {
            XCTFail("Username text field value was nil", file: file, line: line)
            return ""
        }
        return text
    }
    
    @discardableResult
    func assertSavingIndicator(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(savingIndicator, file: file, line: line)
            .waitForNo(savingIndicator, file: file, line: line)
    }
    
    @discardableResult
    func assertNoSavingIndicator(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssert(!savingIndicator.exists, "Found saving indicator when save shouldn't occur", file: file, line: line)
        return self
    }
    
    @discardableResult
    func assertErrorMessage(file: StaticString = #file, line: UInt = #line) -> Self {
        waitFor(errorMessage, file: file, line: line)
    }
    
    @discardableResult
    func assertNoErrorMessage(file: StaticString = #file, line: UInt = #line) -> Self {
        XCTAssert(!errorMessage.exists, "Found error message when it shouldn't exist", file: file, line: line)
        return self
    }
}
