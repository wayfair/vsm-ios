//
//  UserDefaultsDependency.swift
//  Shopping
//
//  Created by Albert Bori on 5/11/22.
//

import Foundation

protocol UserDefaultsDependency {
    var userDefaults: UserDefaults { get }
}

// MARK: Test Support

class StubbedUserDefaults: UserDefaults {
    private var store: [String: Bool] = [:]
    
    override func bool(forKey defaultName: String) -> Bool {
        store[defaultName] ?? false
    }
    
    override func set(_ value: Bool, forKey defaultName: String) {
        store[defaultName] = value
    }
}
