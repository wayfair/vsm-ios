//
//  MockError.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Foundation

struct MockError: Error, LocalizedError {
    var message: String = "Mock Error!"
    
    var errorDescription: String? {
        return message
    }
}
