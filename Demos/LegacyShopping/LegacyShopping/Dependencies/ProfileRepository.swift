//
//  ProfileRepository.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import Foundation

protocol ProfileRepository {
    func loadUsername() async throws -> String
    func save(username: String) async throws -> Void
}

protocol ProfileRepositoryDependency {
    var profileRepository: ProfileRepository { get }
}

//MARK: - Implementation

class ProfileDatabase: ProfileRepository {
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

struct MockProfileRepository: ProfileRepository {
    static var noOp: Self { .init(loadUserNameImpl: { "" }, saveUsernameImpl: { _ in }) }
    
    var loadUserNameImpl: () async throws -> String
    func loadUsername() async throws -> String {
        try await loadUserNameImpl()
    }
    
    var saveUsernameImpl: (String) async throws -> Void
    func save(username: String) async throws {
        try await saveUsernameImpl(username)
    }
}
