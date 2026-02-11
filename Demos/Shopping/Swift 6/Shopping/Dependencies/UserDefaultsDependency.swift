//
//  UserDefaultsDependency.swift
//  Shopping
//
//  Created by Albert Bori on 5/11/22.
//

import Foundation

protocol UserDefaultsDependency: Sendable {
    var userDefaults: UserDefaultsProtocol { get }
}

// MARK: - Sendable UserDefaults Wrapper

/// Protocol abstracting UserDefaults methods used in the app
protocol UserDefaultsProtocol: Sendable {
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func set(_ value: Bool, forKey key: String)
}

/// A Sendable wrapper around UserDefaults
/// UserDefaults is thread-safe internally, so we use @unchecked Sendable
final class UserDefaultsWrapper: UserDefaultsProtocol, @unchecked Sendable {
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
final class StubbedUserDefaults: UserDefaultsProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var boolStore: [String: Bool] = [:]
    private var stringStore: [String: String] = [:]
    
    func bool(forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return boolStore[key] ?? false
    }
    
    func string(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return stringStore[key]
    }
    
    func set(_ value: Bool, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        boolStore[key] = value
    }
    
    func set(_ value: String, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        stringStore[key] = value
    }
}
