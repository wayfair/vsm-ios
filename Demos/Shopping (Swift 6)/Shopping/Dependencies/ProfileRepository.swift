//
//  ProfileRepository.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import Foundation

protocol ProfileRepository: Sendable {
    func loadUsername() async throws -> String
    func save(username: String) async throws -> Void
}

protocol ProfileRepositoryDependency: Sendable {
    var profileRepository: ProfileRepository { get }
}

//MARK: - Implementation

actor ProfileDatabase: ProfileRepository {
    var username = "SomeUser"
    
    func loadUsername() async throws -> String {
        try await Task.sleep(nanoseconds: AppConstants.simulatedNetworkNanoseconds)
        return username
    }
    
    func save(username: String) async throws {
        try await Task.sleep(nanoseconds: AppConstants.simulatedNetworkNanoseconds)
        self.username = username
    }
}

//MARK: Test Support

actor MockProfileRepository: ProfileRepository {
    static var noOp: Self { .init(loadUserNameImpl: { "" }, saveUsernameImpl: { _ in }) }
    
    var loadUserNameImpl: @Sendable () async throws -> String
    var saveUsernameImpl: @Sendable (String) async throws -> Void
    
    init(
        loadUserNameImpl: @escaping @Sendable () async throws -> String,
        saveUsernameImpl: @escaping @Sendable (String) async throws -> Void
    ) {
        self.loadUserNameImpl = loadUserNameImpl
        self.saveUsernameImpl = saveUsernameImpl
    }
    
    func loadUsername() async throws -> String {
        try await loadUserNameImpl()
    }
    
    func save(username: String) async throws {
        try await saveUsernameImpl(username)
    }
}
