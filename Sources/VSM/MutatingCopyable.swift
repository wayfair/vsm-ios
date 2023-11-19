import Foundation

/// Extend a value type with the ability to copy and mutate in a single line of code.
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
///
///     // OR
///
///     func update(username newValue: String) -> Self {
///         // Save username
///         return self.copy(mutating: \.username, value: newValue)
///     }
/// }
/// ```
public protocol MutatingCopyable { }

public extension MutatingCopyable {
    
    /// Creates a mutated copy of this type.
    ///
    /// - Parameter mutator: The function that mutates the copy of this type.
    /// - Returns: A mutated copy of this type.
    func copy(mutating mutator: (inout Self) -> Void) -> Self {
        var copy = self
        mutator(&copy)
        return copy
    }
    
    /// Creates a mutated copy of this type while simultaneously mutating the value at the provided KeyPath.
    ///
    /// - Parameter keyPath: The KeyPath of the property you want to mutate. Please not that this property MUST be a `var` in order to change it's value using this method.
    /// - Parameter value: The new value you want set on the property.
    /// - Returns: A mutated copy of this type.
    func copy<T>(mutatingPath keyPath: WritableKeyPath<Self, T>, value: T) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}
