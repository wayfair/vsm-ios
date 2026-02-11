//
//  Array+SafeSubscript.swift
//  ShoppingTests
//
//  Created by Claude on 2/9/26.
//

import Foundation

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
