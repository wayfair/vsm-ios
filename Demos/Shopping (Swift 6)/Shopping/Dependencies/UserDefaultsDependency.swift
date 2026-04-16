//
//  UserDefaultsDependency.swift
//  Shopping
//
//  Created by Albert Bori on 5/11/22.
//

import Foundation

protocol UserDefaultsDependency {
    var userDefaults: UserDefaultsProtocol { get }
}

// MARK: - UserDefaults Wrapper

/// Protocol abstracting UserDefaults methods used in the app
protocol UserDefaultsProtocol {
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func set(_ value: Bool, forKey key: String)
}

/// Wraps `UserDefaults` behind `UserDefaultsProtocol`.
/// This type is not `Sendable`; it is only used from the app’s UI-scoped dependency graph, not across arbitrary concurrency boundaries.
final class UserDefaultsWrapper: UserDefaultsProtocol {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func bool(forKey key: String) -> Bool {
        userDefaults.bool(forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        userDefaults.string(forKey: key)
    }
    
    func set(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
}

// MARK: - Test Support

/// Test-friendly implementation of UserDefaultsProtocol with in-memory storage
final class StubbedUserDefaults: UserDefaultsProtocol {
    private var boolStore: [String: Bool] = [:]
    private var stringStore: [String: String] = [:]
    
    func bool(forKey key: String) -> Bool {
        return boolStore[key] ?? false
    }
    
    func string(forKey key: String) -> String? {
        return stringStore[key]
    }
    
    func set(_ value: Bool, forKey key: String) {
        boolStore[key] = value
    }
    
    func set(_ value: String, forKey key: String) {
        stringStore[key] = value
    }
}
