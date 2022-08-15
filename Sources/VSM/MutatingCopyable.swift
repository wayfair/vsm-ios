import Foundation

/// Adds the ability to copy and mutate a value type in a single line of code
public protocol MutatingCopyable { }

public extension MutatingCopyable {
    func copy(mutating mutator: (inout Self) -> Void) -> Self {
        var copy = self
        mutator(&copy)
        return copy
    }
}
