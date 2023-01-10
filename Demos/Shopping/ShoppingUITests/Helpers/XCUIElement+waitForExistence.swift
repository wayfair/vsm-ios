//
//  XCUIElement+waitForExistence.swift
//  ShoppingUITests
//
//  Created by Albert Bori on 1/9/23.
//

import XCTest

extension XCUIElement {
    private var maxWaitCount: Int { 50 }
    
    /// Searches for an element for up  to 5 seconds. Returns the instant that the element is found or when the search times out.
    /// - Parameter hittable: Conditionally require if the item should be hittable (defaults to `true`)
    /// - Returns: Returns true if the element was found and is appropriately hittable (if specified). Otherwise returns false.
    func waitForExistence(hittable: Bool = true) -> Bool {
        for _ in 1...maxWaitCount {
            if exists && (!hittable || isHittable) { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }
    
    /// Searches for an element for up  to 5 seconds. Returns the instant that the element is no longer found or when the search times out.
    /// - Returns: Returns true if the element was not found. Otherwise returns false.
    func waitForNonexistence() -> Bool {
        for _ in 1...maxWaitCount {
            if !exists { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }
}
