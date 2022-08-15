//
//  AsyncResource.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import Foundation

class AsyncResource<Resource>: ObservableObject {
    enum State {
        case loading
        case loaded(Resource)
        case error(Error)
    }
    
    @Published private(set) var state: State = .loading
    
    init(_ load: @escaping () async throws -> Resource) {
        Task {
            do {
                let value = try await load()
                state = .loaded(value)
            } catch {
                state = .error(error)
            }
        }
    }
}

class ReloadableAsyncResource<Resource>: ObservableObject {
    enum State {
        case loading
        case loaded(Resource)
        case error(Error)
        case reloading
        case reloadingError(Error)
        
        var isLoading: Bool {
            switch self {
            case .loading, .reloading:
                return true
            default:
                return false
            }
        }
    }
    
    @Published private(set) var state: State = .loading
    private let reload: () async throws -> Resource
    
    init(_ load: @escaping () async throws -> Resource) {
        reload = load
        Task {
            do {
                let value = try await load()
                state = .loaded(value)
            } catch {
                state = .error(error)
            }
        }
    }
    
    func reload() async {
        do {
            let value = try await reload()
            state = .loaded(value)
        } catch {
            state = .error(error)
        }
    }
}
