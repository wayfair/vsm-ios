//
//  ProfileViewState.swift
//  Shopping
//
//  Created by Albert Bori on 1/26/23.
//

import Combine
import VSM

// MARK: - State & Model Definitions

enum ProfileViewState {
    case initialized(ProfileLoaderModeling)
    case loading
    case editing(ProfileEditingModeling)
}

protocol ProfileLoaderModeling {
    var error: String? { get }
    func load() async -> StateSequence<ProfileViewState>
}

protocol ProfileEditingModeling {
    var username: String { get }
    var editingState: ProfileEditingState { get }
    func save(username: String) async -> StateSequence<ProfileViewState>
}

// MARK: - Model Implementations

struct ProfileLoaderModel: ProfileLoaderModeling {
    typealias Dependencies = ProfileRepositoryDependency
    let dependencies: Dependencies
    let error: String?
    
    func load() async -> StateSequence<ProfileViewState> {
        return StateSequence<ProfileViewState>(
            { .loading },
            {
                do {
                    let username = try await dependencies.profileRepository.loadUsername()
                    return .editing(ProfileEditingModel(dependencies: dependencies,
                                                        username: username,
                                                        editingState: .editing))
                } catch {
                    return .initialized(ProfileLoaderModel(dependencies: dependencies,
                                                           error: error.localizedDescription))
                }
            }
        )
    }
}

struct ProfileEditingModel: ProfileEditingModeling, MutatingCopyable {
    typealias Dependencies = ProfileRepositoryDependency
    let dependencies: Dependencies
    var username: String
    var editingState: ProfileEditingState
    
    func save(username: String) async -> StateSequence<ProfileViewState> {
        guard username != self.username else {
            return StateSequence({ ProfileViewState.editing(self) })
        }
        guard !username.isEmpty else {
            return StateSequence({
                ProfileViewState.editing(self.copy(mutating: { $0.editingState = .error(Errors.emptyUsername) }))
            })
        }
        return StateSequence<ProfileViewState>(
            {
                return .editing(self.copy(mutating: { $0.editingState = .saving }))
            },
            {
                do {
                    try await dependencies.profileRepository.save(username: username)
                    return .editing(self.copy(mutating: {
                        $0.editingState = .editing
                        $0.username = username
                    }))
                } catch {
                    return .editing(self.copy(mutating: { $0.editingState = .error(error) }))
                }
            }
        )
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
