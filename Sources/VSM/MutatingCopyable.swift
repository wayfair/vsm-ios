import Foundation

/// A marker protocol that adds ergonomic "copy, then change, then return" helpers for value types.
///
/// Swift structs and enums are copied by default, but updating several properties usually means spelling
/// out a local `var`, assigning fields, and returning it. ``MutatingCopyable`` does not require any
/// implementation from conforming types; the protocol exists only to attach default implementations of
/// ``copy(mutating:)`` and ``copy(mutatingPath:value:)`` via an extension. Those methods produce a new
/// instance by applying your mutations to a copy, so callers can keep an immutable style (methods that
/// return `Self` or a new model) without repetitive boilerplate.
///
/// ### When to use it
///
/// Use ``MutatingCopyable`` when you want small, readable updates to a value type—especially in feature
/// models, view state, or other types whose API prefers returning a new value instead of mutating
/// `self` in place. The closure-based ``copy(mutating:)`` fits multi-field or conditional updates; the
/// key-path overload is convenient for a single property change.
///
/// ### Example usage
///
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
///         return self.copy(mutatingPath: \.username, value: newValue)
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
    /// - Parameter keyPath: The key path of the property you want to mutate. The property must be a `var` so it can be written through this method.
    /// - Parameter value: The new value you want set on the property.
    /// - Returns: A mutated copy of this type.
    func copy<T>(mutatingPath keyPath: WritableKeyPath<Self, T>, value: T) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}
