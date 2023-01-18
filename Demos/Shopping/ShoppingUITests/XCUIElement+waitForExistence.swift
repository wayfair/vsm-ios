//
//  XCUIElement+waitForExistence.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/9/23.
//

import XCTest

extension XCUIElement {
    
    private enum Constants {
        static var defaultTimeout: TimeInterval = 5.0
        static var waitInterval: TimeInterval = 0.1
    }
    
    /// Searches for an element. Returns the instant that the element is found or when the search times out. (5 second default timeout)
    /// - Parameter hittable: Conditionally require if the item should be hittable (defaults to `true`)
    /// - Parameter enabled: Conditionally require if the item should be enabled (defaults to `true`)
    /// - Parameter timeout: The maximum amount of time to wait. Defaults to 5 seconds
    /// - Returns: Returns true if the element was found and is appropriately hittable (if specified). Otherwise returns false
    func waitForExistence(hittable: Bool = true,
                          enabled: Bool = true,
                          timeout: TimeInterval = Constants.defaultTimeout) -> Bool {
        for _ in 1...Int((timeout/Constants.waitInterval).rounded(.up)) {
            if exists && (!hittable || isHittable) && (!enabled || isEnabled) { return true }
            Thread.sleep(forTimeInterval: Constants.waitInterval)
        }
        return false
    }
    
    /// Searches for an element. Returns the instant that the element is no longer found or when the search times out. (5 second default timeout)
    /// - Parameter timeout: The maximum amount of time to wait. Defaults to 5 seconds
    /// - Returns: Returns true if the element was not found. Otherwise returns false
    func waitForNonexistence(timeout: TimeInterval = Constants.defaultTimeout) -> Bool {
        for _ in 1...Int((timeout/Constants.waitInterval).rounded(.up)) {
            if !exists { return true }
            Thread.sleep(forTimeInterval: Constants.waitInterval)
        }
        return false
    }
}
