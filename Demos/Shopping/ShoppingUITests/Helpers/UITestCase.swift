//
//  UITestCase.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/18/23.
//

import XCTest

open class UITestCase: XCTestCase {
    var app: XCUIApplication!
    var mainPage: MainPage { MainPage(app: app) }
    
    open override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS" : "YES",
            "RESET_USER_DEFAULTS": "YES"
        ]
        app.launch()
    }
    
    open override func tearDownWithError() throws {
        try super.tearDownWithError()
        app = nil
    }
}
