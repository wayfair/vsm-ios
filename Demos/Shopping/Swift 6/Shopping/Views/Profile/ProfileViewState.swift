//
//  ProfileViewState.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import VSM

// MARK: - State & Model Definitions

enum ProfileViewState: Sendable {
    case initialized(ProfileLoaderModel)
    case loading
    case loaded(ProfileLoadedModel)
    case editing(ProfileEditingModel)
    
    var isSaving: Bool {
        guard case .editing(let editingModel) = self else { return false }
        guard case .saving = editingModel.editingState else { return false }
        
        return true
    }
    
    var errorMessage: String? {
        guard case .editing(let editingModel) = self else { return nil }
        return editingModel.editingState.errorMessage
    }
}

// MARK: - Model Implementations

struct ProfileLoaderModel: Sendable {
    typealias Dependencies = ProfileRepositoryDependency
    let dependencies: Dependencies
    let error: String?
    
    @StateSequenceBuilder
    func load() -> StateSequence<ProfileViewState> {
        ProfileViewState.loading
        Next { await performLoad() }
    }
    
    @concurrent
    private func performLoad() async -> ProfileViewState {
        do {
            let username = try await dependencies.profileRepository.loadUsername()
            return ProfileViewState.loaded(ProfileLoadedModel(
                dependencies: dependencies,
                fetchedUsername: username
            ))
        } catch {
            return ProfileViewState.initialized(ProfileLoaderModel(
                dependencies: dependencies,
                error: error.localizedDescription
            ))
        }
    }
}

struct ProfileLoadedModel: Sendable {
    typealias Dependencies = ProfileRepositoryDependency
    let dependencies: Dependencies
    let fetchedUsername: String

    func startEditing() -> ProfileViewState {
        return .editing(ProfileEditingModel(
            dependencies: dependencies,
            username: fetchedUsername,
            editingState: .editing
        ))
    }
}

struct ProfileEditingModel: Sendable, MutatingCopyable {
    typealias Dependencies = ProfileRepositoryDependency
    let dependencies: Dependencies
    var username: String
    var editingState: ProfileEditingState
    
    @StateSequenceBuilder
    func save(username: String) -> StateSequence<ProfileViewState> {
        if username == self.username {
            ProfileViewState.editing(self)
        } else if username.isEmpty {
            ProfileViewState.editing(self.copy(mutating: { $0.editingState = .error(Errors.emptyUsername) }))
        } else {
            ProfileViewState.editing(self.copy(mutating: { $0.editingState = .saving }))
            Next { await performSave(username: username) }
        }
    }
    
    @concurrent
    private func performSave(username: String) async -> ProfileViewState {
        do {
            try await dependencies.profileRepository.save(username: username)
            let updatedViewState = self.copy(mutating: {
                $0.editingState = .editing
                $0.username = username
            })
            return ProfileViewState.editing(updatedViewState)
        } catch {
            return ProfileViewState.editing(self.copy(mutating: { $0.editingState = .error(error) }))
        }
    }
    
    enum Errors: Error {
        case emptyUsername
    }
}

enum ProfileEditingState {
    case editing
    case saving
    case error(Error)
    
    var errorMessage: String? {
        if case .error(let error) = self {
            switch error {
            case ProfileEditingModel.Errors.emptyUsername:
                return "Username must not be empty."
            default:
                return error.localizedDescription
            }
        }
        return nil
    }
    
    var isError: Bool { errorMessage != nil }
}
