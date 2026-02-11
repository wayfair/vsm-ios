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
        app.launchArguments += ["-UITesting"]
        
        let frameworkArgs: Set<String> = ["-ui-framework", "uikit"]
        app.launchArguments += ProcessInfo.processInfo.arguments.filter({ frameworkArgs.contains($0) })
        app.launch()
    }
    
    open override func tearDownWithError() throws {
        try super.tearDownWithError()
        app = nil
    }
}
