# Unit Testing a VSM Feature

A guide to writing unit tests that validate requirements in VSM features

## Overview

The type safety of the VSM architecture pattern prevents several categories of bugs from being introduced into the feature code. Despite this, there is still a chance that an engineer did not correctly implement the view state progression as described in the feature requirements.

Unit tests provide additional peace of mind that the engineer implemented the feature correctly. Unit tests also provide a safeguard against future regressions.

## Mocking the Data Repositories

Your observable data repositories should be designed in such a way that they can be mocked for testing. Mocking is the act of substituting a fake version of a piece of code which can be injected into a test subject to support testing the test subject.

Mocks generally allow the code within the unit test to provide a fake implementation that supports the unit test subject and prevents the unit test from accessing any ancillary resources that are not pertinent to the test. There are three common ways to design your data repositories to be mockable: protocols, structs with injectable implementations, or "stubs" that let you override certain aspects of the repository's behavior.

> Tip: Mocks should **_never_** include any business logic of any kind. They are purely [inversion-of-control](https://en.wikipedia.org/wiki/Inversion_of_control) types which exist solely to isolate a test subject from the implementation code of its dependencies while in a unit test.

### Mocking with Protocols

The most common form of designing for mockable testing is to use protocols that expose the properties and functions of the repository which are to be used broadly. Reference these repositories by their protocol instead of their concrete type. This allows you to create special mock implementations of the repository which can be injected into the test subject while unit testing.

A protocol and its accompanying mock type may look like this:

```swift
protocol UserDataProviding {
    func load() -> AnyPublisher<UserData, Error>
}

struct MockUserDataProviding: UserDataProviding {
    var loadResult: AnyPublisher<UserData, Error>
    func load() -> AnyPublisher<UserData, Error> {
        return loadResult ?? Empty()
    }
}
```

Notice how the mock provides a mutable property called `loadResult` which lets you set the expected return value of the `load()` function. If no return value is specified by the test, it defaults to do nothing. This is often called "no-op" or "no operation".

### Mocking with Structs

An acceptable substitution for designing with protocols is to use structs whose implementation is settable or injectable during or after their construction. The benefit of these is that you don't need a separate mock type to be able to use them in testing.

An example of a repository using this approach is:

```swift
struct UserDataRepository {
    var load: () -> AnyPublisher<UserData, Error>
    init() {
        load = {
            // real implementation is defined here
        }
    }
}
```

These can be easily mocked in a test using the following code:

```swift
let mockRepository = UserDataRepository(load: { Empty() })
```

### Mocking with Stubs

Stubs are not true mocks. Instead, they are a concrete implementation (usually a class) that allows some parts of the real implementation to be configured to do special things within a test scenario. This approach is not recommended due to the pollution of production code with test conditions sprinkled throughout. They are difficult to maintain and can easily introduce bugs. It is also easy to accidentally access production resources if the stub is incorrectly configured by the unit test code.

## Writing the Unit Test

To unit test a VSM feature, you must construct the model that you wish to test, mocking any of its dependencies at the desired level. This model will be the test subject for the unit test. Then, you should call the action in question on the subject and compare its output to the desired result.

```swift
func testUserProfileLoad() throws {
    let expectedUserData = UserData(username: "test")
    let mockRepository = MockDataRepository(loadResult: Just(expectedUserData))
    let subject = LoadUserProfileViewState.LoaderModel(repository: mockRepository)
    let output = subject.load()
    let testExpectation = XCTestExpectation(description: "Load Publisher")
    testExpectation.expectedFulfillmentCount = 3
    var results: [LoadUserProfileViewState] = []
    output.sink { result in
        testExpectation.fulfill()
    } receiveValue: { value in
        results.append(value)
        testExpectation.fulfill()
    }
    .store(in: &subscriptions)

    let firstViewState = try XCTUnwrap(results.first)
    switch firstViewState {
    case .loading:
        break
    default:
        XCTFail("Expected loading state but got \(firstViewState)")
    }
    
    let secondViewState = try XCTUnwrap(results.last)
    switch secondViewState {
    case .loaded(let userData):
        XCTAssertEqual(userData, expectedUserData)
    default:
        XCTFail("Expected loaded state but got \(secondViewState)")
    }
}
```

The above test calls the `LoadUserProfileViewState.LoaderModel`'s load function and asserts that the loading view state and the loaded state are emitted before the publisher finishes.

To consider the feature "fully tested", a test should be written for every model and action to validate that every possible view state output (including error states) is correctly emitted when called, and that the appropriate data is associated with the view states.

## Easier Unit Testing

The above example is quite verbose. Fortunately, there are a few techniques that we can take advantage of to greatly reduce the volume of code required per unit test.

### Equatable View States

In order to more easily test a VSM feature, it is recommended that you conform your view state type to the `Equatable` protocol, even if just within your unit test target. This will allow you to compare states by simply using the XCTest APIs, such as `XCTAssertEqual`.

An example view state implementation of equatable will look something like this:

```swift
extension LoadUserProfileViewState: Equatable {
    public static func == (lhs: LoadUserProfileViewState, rhs: LoadUserProfileViewState) -> Bool {
        switch (lhs, rhs) {
        case (.initialized, .initialized):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsData), .loaded(let rhsData)):
            return lhsData == rhsData
        case (.loadingError(let lhsModel), .loadingError(let rhsModel)):
            return lhsModel.message == rhsModel.message
        default:
            return false
        }
    }
}
```

This makes the above unit test much more concise:

```swift
func testUserProfileLoad() throws {
    let expectedUserData = UserData(username: "test")
    let mockRepository = MockDataRepository(loadResult: Just(expectedUserData))
    let subject = LoadUserProfileViewState.LoaderModel(repository: mockRepository)
    let output = subject.load()
    let testExpectation = XCTestExpectation(description: "Load Publisher")
    testExpectation.expectedFulfillmentCount = 3
    var results: [LoadUserProfileViewState] = []
    output.sink { result in
        testExpectation.fulfill()
    } receiveValue: { value in
        results.append(value)
        testExpectation.fulfill()
    }
    .store(in: &subscriptions)

    XCTAssertEqual(results, [.loading, .loaded(expectedUserData)])
}
```

> Tip: It is possible, using protocol-oriented programming and reflection, to write a protocol that provides a default `Equatable` implementation that can be applied to any type via Swift type extensions. This may be worth while to develop for yourself if you find it tedious to implement equatable on all of the view state types in your app.
>
> The approach would look something like:
> ```swift
> public protocol UnitTestEquatable: Equatable { }
>
> public extension UnitTestEquatable {
>     static func == (lhs: Self, rhs: Self) -> Bool {
>         // TODO: reflect the type and properties to compare their values recursively
>     }
> }
> 
> extension SomeViewState: UnitTestEquatable { /*no-op*/ }
> ```

## Testing Combine Publishers

Combine publishers are notoriously difficult and verbose to test. This is because they are inherently asynchronous and guarantee no specific behavior by their type signature. A publisher may emit many results or none. A throwing publisher may finish with an error, or never finish at all. Finally, merged publishers may not emit values to subscribers in a predictable order.

As you can see from the unit test examples above, there is quite a bit of boilerplate code required to unit test a single publisher. Considering how many unit tests that will need to be written to validate the output of every action for a VSM feature, this can result in a _ton_ of verbose unit test code.

The good news is that there is a library called [Testable Combine Publishers](https://github.com/albertbori/TestableCombinePublishers) which allows you to write unit tests for Combine publishers with _significantly_ less code. Since many of your VSM actions will return publishers, it may be a good idea to import this library into your test targets.

The above unit test example, written with both Equatable View States and Testable Combine Publishers, will end up being as simple as:

```swift
func testUserProfileLoad() throws {
    let expectedUserData = UserData(username: "test")
    let mockRepository = MockDataRepository(loadResult: Just(expectedUserData))
    let subject = LoadUserProfileViewState.LoaderModel(repository: mockRepository)
    subject.load()
        .collect(2)
        .expect([.loading, .loaded(expectedUserData)])
        .expectSuccess()
        .waitForExpectations(timeout: 10)
}
```

> Tip: Be sure to use the ["Test Repeatedly"](https://www.avanderlee.com/debugging/flaky-tests-test-repetitions/) feature in Xcode to ensure that your Combine unit tests do not have flaky assertions.

## Behavior-driven Development

[Behavior-driven Development](https://en.wikipedia.org/wiki/Behavior-driven_development) (BDD) is an approach where writing intentionally-failing unit tests is part of requirements gathering process. VSM development shares some concepts with BDD in that you have to have a deep understanding of the requirements to build the shape of the feature before you can start implementing the view or the models. While BDD is not explicitly required for VSM, it may be a good option to consider adding to your process.

If you decide to use BDD, the following is a good process to follow:

1. Build the shape of the feature states (see <doc:StateDefinition>)
1. Build and mock the protocols for the data repositories that the feature requires
1. Write failing unit tests against the view states and model definitions
1. Once you are confident that your tests are correct, implement the view, models, and repositories that will ultimately make these tests pass

Use the above exercise as a way to discover any gaps or discrepancies in the requirements.

> Note: Building features with BDD does have one major drawback: You are starting with tech debt. Your tests will likely be incorrect and need to be changed as you refine the requirements, view, and implementation details. It is up to your team to decide if this up-front cost is worth the investment.

## Conclusion

This concludes the <doc:ComprehensiveGuide>. For further reading, feel free to browse the VSM Reference articles or API documentation found in the <doc:VSM> document directory.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
