//
//  AsyncDataState.swift
//  Shopping
//
//  Created by Albert Bori on 2/25/22.
//

import Foundation

enum AsyncDataState<Data, ErrorType: Error> {
    case loading
    case loaded(Data)
    case error(ErrorType)
}

extension AsyncDataState {
    func map<Output>(_ transform: (Data) -> Output) -> AsyncDataState<Output, ErrorType> {
        switch self {
        case .loading:
            return .loading
        case .loaded(let data):
            return .loaded(transform(data))
        case .error(let error):
            return .error(error)
        }
    }
}
