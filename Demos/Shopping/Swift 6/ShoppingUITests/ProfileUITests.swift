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
        let profilePage = mainPage
            .defaultTab()
            .tapAccountsTab()
            .tapProfile()
        
        // Wait for the profile to load and verify initial state
        profilePage.waitForInitialLoad()
        
        profilePage
            .clearUsernameField()
            .assert(username: "User Name")
            .assertNoSavingIndicator()
            .assertErrorMessage()
            .type(username: "FooBar")
            .assertSavingIndicator()
            .assertNoErrorMessage()
            .tapBackButton()
            .tapProfile()
            .waitForInitialLoad()
            .assert(username: "FooBar")
    }
}
