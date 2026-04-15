//
//  ProfileUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/26/23.
//

import XCTest

final class ProfileUITests: UITestCase {
    
    func testUsernameEditing() {
        /// Checks that the error and saving states correctly show, and that the value is persistent after navigating away
        mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapProfile()
            .assert(username: "SomeUser")
            .clearUsernameField()
            .assert(username: "User Name")
            .assertNoSavingIndicator()
            .assertErrorMessage()
            .type(username: "FooBar")
            .assertSavingIndicator()
            .assertNoErrorMessage()
            .tapBackButton()
            .tapProfile()
            .assert(username: "FooBar")
    }
}
