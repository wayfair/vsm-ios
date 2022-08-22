import Foundation

/// Extend a value type with the ability to copy and mutate in a single line of code
///
/// Example Usage
/// ```swift
/// struct UserState: MutatingCopyable {
///     var username: String
///
///     func change(username: String) -> Self {
///         // Save username
///         return self.copy(mutating: { $0.username = username })
///     }
/// }
/// ```
public protocol MutatingCopyable { }

public extension MutatingCopyable {
    
    /// Creates a mutated copy of this type
    /// 
    /// - Parameter mutator: The function that mutates the copy of this type
    /// - Returns: A mutated copy of this type
    func copy(mutating mutator: (inout Self) -> Void) -> Self {
        var copy = self
        mutator(&copy)
        return copy
    }
}
