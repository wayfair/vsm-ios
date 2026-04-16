# Unit Testing a VSM Feature

A guide to writing unit tests that validate requirements in VSM features

## Overview

The type safety of the VSM architecture pattern prevents several categories of bugs from being introduced into the feature code. Despite this, there is still a chance that an engineer did not correctly implement the view state progression as described in the feature requirements.

Unit tests provide additional peace of mind that the engineer implemented the feature correctly. Unit tests also provide a safeguard against future regressions.

## Mocking the Data Repositories

Your data repositories should be designed in such a way that they can be mocked for testing. Mocking is the act of substituting a fake version of a piece of code that can be injected into a test subject to support testing the test subject.

Mocks generally allow the code within the unit test to provide a fake implementation that supports the unit test subject and prevents the unit test from accessing any ancillary resources that are not pertinent to the test. There are three common ways to design your data repositories to be mockable: protocols, structs with injectable implementations, or "stubs" that let you override certain aspects of the repository's behavior.

> Tip: Mocks should **_never_** include any business logic of any kind. They are purely [inversion-of-control](https://en.wikipedia.org/wiki/Inversion_of_control) types which exist solely to isolate a test subject from the implementation code of its dependencies while in a unit test.

### Mocking with Protocols

The most common form of designing for mockable testing is to use protocols that expose the properties and functions of the repository which are to be used broadly. Reference these repositories by protocol instead of their concrete type. This allows you to create special mock implementations of the repository which can be injected into the test subject while unit testing.

A protocol and its accompanying mock type may look like this:

```swift
protocol UserDataProviding {
    func load() async throws -> UserData
}

struct MockUserDataProviding: UserDataProviding {
    var loadImpl: () async throws -> UserData
    
    func load() async throws -> UserData {
        try await loadImpl()
    }
}
```

Notice how the mock provides a mutable property called `loadImpl` which lets you set the expected behavior of the `load()` function. This closure can be configured in tests to return specific values or throw errors.

### Mocking with Structs

An acceptable substitution for designing with protocols is to use structs whose implementation is settable or injectable during or after their construction. The benefit of these is that you don't need a separate mock type to be able to use them in testing.

An example of a repository using this approach is:

```swift
struct UserDataRepository {
    var load: () async throws -> UserData
    
    init() {
        load = {
            // real implementation is defined here
        }
    }
}
```

These can be easily mocked in a test using the following code:

```swift
let mockRepository = UserDataRepository(
    load: { UserData(username: "test") }
)
```

### Mocking with Stubs

Stubs are not true mocks. Instead, they are a concrete implementation (usually a class) that allows some parts of the real implementation to be configured to do special things within a test scenario. This approach is not recommended due to the pollution of production code with test conditions sprinkled throughout. They are difficult to maintain and can easily introduce bugs. It is also easy to accidentally access production resources if the stub is incorrectly configured by the unit test code.

## Writing the Unit Test

To unit test a VSM feature, you must construct the model that you wish to test, mocking any of its dependencies at the desired level. This model will be the test subject for the unit test. Then, you should call the action in question on the subject and compare its output to the desired result.

VSM 2.0 uses the Swift Testing framework, which provides a modern, concise syntax for writing tests. Here's an example of testing a model that returns a `StateSequence`:

```swift
import Testing
@testable import YourApp

struct UserProfileTests {
    
    @Test("LoaderModel loads user profile successfully")
    func testUserProfileLoad() async throws {
        let expectedUserData = UserData(username: "test")
        let mockRepository = MockUserDataProviding(
            loadImpl: { expectedUserData }
        )
        let subject = LoaderModel(repository: mockRepository)
        
        var states: [LoadUserProfileViewState] = []
        let stateSequence = subject.load()
        
        // Collect states from the StateSequence
        for await state in stateSequence {
            states.append(state)
        }
        
        #expect(states.count == 2, "Expected 2 states but got \(states.count)")
        
        guard case .loading = states.first else {
            Issue.record("Expected first state of .loading, but got: \(states)")
            return
        }
        
        guard case .loaded(let userData) = states.last else {
            Issue.record("Expected last state of .loaded, but got: \(states)")
            return
        }
        
        #expect(userData.username == expectedUserData.username)
    }
}
```

The above test calls the `LoaderModel`'s load function and asserts that the loading view state and the loaded state are emitted from the `StateSequence`.

To consider the feature "fully tested", a test should be written for every model and action to validate that every possible view state output (including error states) is correctly emitted when called and that the appropriate data is associated with the view states.

## Testing Different Action Types

VSM 2.0 models can return different types of values depending on the action. Here are patterns for testing each type:

### Testing StateSequence Actions

Most async actions in VSM return a `StateSequence`, which emits multiple states over time. A `StateSequence` may contain both **synchronous** and **asynchronous** states (especially when built with `@StateSequenceBuilder`). Synchronous states are stored in `synchronousStateActions` and are not yielded by the `AsyncIteratorProtocol` — they are applied inline by the container. When unit testing, you should verify both:

```swift
import Testing
@testable import Shopping

@Test("ProductsLoaderModel loads products successfully")
func testLoadSuccess() async throws {
    let mockRepository = await MockProductRepository.noOp()
    let subject = ProductsLoaderModel(dependencies: mockRepository)
    
    let stateSequence = subject.loadProducts()
    
    // Verify synchronous states (applied inline by the container)
    let syncStates = stateSequence.synchronousStateActions.map { $0() }
    #expect(syncStates.count == 1, "Expected 1 synchronous state")
    guard case .loading = syncStates.first else {
        Issue.record("Expected synchronous state of .loading")
        return
    }
    
    // Verify asynchronous states (applied inside a Task by the container)
    var asyncStates: [ProductsViewState] = []
    var iterator = stateSequence.makeAsyncIterator()
    while let state = try await iterator.next() {
        asyncStates.append(state)
    }
    
    #expect(asyncStates.count == 1, "Expected 1 async state but got \(asyncStates.count)")
    
    guard case .loaded = asyncStates[0] else {
        Issue.record("Expected async state of .loaded, but got: \(asyncStates)")
        return
    }
}
```

> Note: This snippet is written against the **Shopping (Swift 6)** demo module (`@testable import Shopping`) so it stays copy-paste accurate for that target. In your own app, substitute your module name, types, and mocks.

> Note: If the action was built with the variadic initializer or array-literal syntax (where all closures are async), all states will be yielded by the async iterator and `synchronousStateActions` will be empty. The approach above works for both creation styles.

### Testing Error Handling

Test error cases by configuring your mocks to throw errors:

```swift
@Test("AddToCartModel handles errors correctly")
func testAddToCartError() async throws {
    let mockRepository = MockCartRepository(
        addProductToCartImpl: { _ in
            throw MockError(message: "Test error")
        }
    )
    let subject = AddToCartModel(repository: mockRepository, productId: 0)
    
    var states: [ProductDetailViewState] = []
    var iterator = subject.addToCart().makeAsyncIterator()
    
    // Collect the error states
    if let state1 = await iterator.next() {
        states.append(state1)
    }
    if let state2 = await iterator.next() {
        states.append(state2)
    }
    
    guard case .addingToCart = states[0] else {
        Issue.record("Expected first state of .addingToCart")
        return
    }
    
    guard case .addToCartError(let message, _) = states[1] else {
        Issue.record("Expected second state of .addToCartError")
        return
    }
    
    #expect(message.contains("Test error"))
}
```

> Note: The `AddToCartModel` example above is **illustrative** (it uses a `repository:` parameter and a struct-shaped mock). The Shopping (Swift 6) demo uses `AddToCartModel(dependencies:)` with an **actor** `MockCartRepository` and a **three-step** `StateSequence` (`addingToCart` → add → resume). Adjust the mock, initializer, and how many `iterator.next()` calls you expect when copying from production code.

### Testing Synchronous Actions

Some actions return a single state synchronously. These are straightforward to test:

```swift
import Testing
@testable import Shopping

@Test("ProductsLoadedModel handles navigation to product detail")
func testNavigation() throws {
    let subject = ProductsLoadedModel(products: [], productDetailId: nil)
    let output = subject.showProductDetail(id: 1)
    
    guard case .loaded(let loadedModel) = output else {
        Issue.record("Expected state of .loaded, but got: \(output)")
        return
    }
    
    #expect(loadedModel.productDetailId == 1)
}
```

### Testing AsyncStream Observations

Some features use `AsyncStream` (or another `AsyncSequence`) for **ongoing** values—live counts, push-style invalidations—then map results into view state with `$state.observe(...)` (or a thin `@MainActor` bridge). Test `for await` consumption with a **timeout** so a broken mock cannot hang CI.

The example below is intentionally **self-contained**. In the **Shopping (Swift 6)** demo, live cart count is vended from the cart repository (`cartCountStream()` yields `AsyncStream<Int>`); there is no `MainViewLoadedModel.observeCardCount()`—apply the same timeout pattern when testing your stream or mapping layer.

```swift
import Testing

@Test("AsyncStream observation completes under a timeout")
func testObservingFiniteStream() async throws {
    let stream = AsyncStream<Int> { continuation in
        continuation.yield(3)
        continuation.finish()
    }

    var received = false

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            for await value in stream.prefix(1) {
                received = true
                #expect(value == 3)
                break
            }
        }

        group.addTask {
            try await Task.sleep(for: .seconds(5))
            throw TimeoutError()
        }

        try await group.next()
        group.cancelAll()
    }

    #expect(received)
}

private struct TimeoutError: Error {}
```

## Testing Best Practices

### Using @MainActor When Needed

Some models may require execution on the main actor. Mark your tests with `@MainActor` when testing such models:

```swift
import Testing
@testable import Shopping

@Test("DependenciesLoaderModel loads dependencies", .timeLimit(.minutes(1)))
@MainActor
func testLoad() async throws {
    let mockedDependenciesProvider = MockDependenciesProvider(
        dependencies: MockAppDependencies.noOp()
    )
    let subject = DependenciesLoaderModel(
        dependenciesProvider: mockedDependenciesProvider
    )
    
    var states: [MainViewState] = []
    let stateSequence = subject.loadDependencies()
    
    for await state in stateSequence {
        states.append(state)
    }
    
    #expect(states.count == 2)
    guard case .loading = states.first else {
        Issue.record("Expected first state of .loading")
        return
    }
    guard case .loaded = states.last else {
        Issue.record("Expected last state of .loaded")
        return
    }
}
```

### Using Time Limits

Add time limits to prevent tests from hanging indefinitely:

```swift
@Test("LoaderModel completes within time limit", .timeLimit(.seconds(30)))
func testWithTimeLimit() async throws {
    // Your test code here
}
```

### Safe Array Access

When accessing states by index, use a safe subscript helper to avoid crashes:

```swift
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Usage in tests
guard case .loading = states[safe: 0] else {
    Issue.record("Expected first state of .loading")
    return
}
```

## Behavior-driven Development

[Behavior-driven Development](https://en.wikipedia.org/wiki/Behavior-driven_development) (BDD) and [Test-driven Development](https://en.wikipedia.org/wiki/Test-driven_development) (TDD) are techniques that begin feature development by writing intentionally-failing unit tests as part of the development process. For BDD, the tests are written using a language like [Gherkin](https://en.wikipedia.org/wiki/Cucumber_(software)) which is then automatically interpreted into test script actions.

VSM development shares some concepts with BDD in that you should deeply understand the requirements and convert those requirements into Swift types (ie, the "shape of the feature") before you can start implementing the view or the models. While BDD and TDD are not required by VSM, these techniques may be good options to consider.

If you decide to use BDD or TDD with VSM, these steps can help you get started:

1. Build the shape of the feature states (see <doc:StateDefinition>)
1. Build and mock the protocols for the data repositories that the feature requires
1. Write failing unit tests against the view states and model definitions using the Swift Testing framework
1. Once you are confident that your tests are correct, implement the view, models, and repositories that will ultimately make these tests pass

Use the above exercise as a way to discover any gaps or discrepancies in the requirements.

> Note: Building features with BDD and TDD has a non-trivial tradeoff that's worth consideration: You are starting with technical debt. Your tests will likely be incorrect and need to be changed as you refine the requirements, UI, and implementation details. It is up to your team to decide if this up-front cost is worth the investment.
>
> As you develop features in VSM, you may find the process of defining and refining the "shape of the feature" to be an acceptable alternative to fully adopting BDD or TDD.

## Conclusion

This concludes the <doc:ComprehensiveGuide>. For further reading, feel free to browse the VSM Reference articles or API documentation found in the <doc:VSM> document directory.

### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
