//
//  SettingsUITests.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/10/23.
//

import XCTest
@testable import Shopping

final class SettingsUITests: UITestCase {
    
    func testToggleStates() {
        // Tests that each of the toggles work and hold their values between navigations
        mainPage
            .tapAccountsTab()
            .tapSettings()
            .assertSetting(.convenienceBinding1, isOn: false)
            .assertSetting(.convenienceBinding2, isOn: false)
            .assertSetting(.customBinding, isOn: false)
            .assertSetting(.stateBinding, isOn: false)
            .toggleSetting(.convenienceBinding1)
            .toggleSetting(.convenienceBinding2)
            .toggleSetting(.customBinding)
            .toggleSetting(.stateBinding)
            .assertSetting(.convenienceBinding1, isOn: true)
            .assertSetting(.convenienceBinding2, isOn: true)
            .assertSetting(.customBinding, isOn: true)
            .assertSetting(.stateBinding, isOn: true)
            .tapBackButton()
            .tapSettings()
            .assertSetting(.convenienceBinding1, isOn: true)
            .assertSetting(.convenienceBinding2, isOn: true)
            .assertSetting(.customBinding, isOn: true)
            .assertSetting(.stateBinding, isOn: true)
    }
}
