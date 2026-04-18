//
//  ProfileRepository.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import Foundation

protocol ProfileRepository: Actor {
    func loadUsername() async throws -> String
    func save(username: String) async throws -> Void
}

protocol ProfileRepositoryDependency {
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

/// Test and preview stand-in; stub closures run on this actor’s executor.
actor MockProfileRepository: ProfileRepository {
    init(
        loadUserNameImpl: @escaping () async throws -> String,
        saveUsernameImpl: @escaping (String) async throws -> Void
    ) {
        self.loadUserNameImpl = loadUserNameImpl
        self.saveUsernameImpl = saveUsernameImpl
    }
    
    nonisolated static func noOp() -> MockProfileRepository {
        MockProfileRepository(loadUserNameImpl: { "" }, saveUsernameImpl: { _ in })
    }
    
    let loadUserNameImpl: () async throws -> String
    let saveUsernameImpl: (String) async throws -> Void
    
    func loadUsername() async throws -> String {
        try await loadUserNameImpl()
    }
    
    func save(username: String) async throws {
        try await saveUsernameImpl(username)
    }
}
