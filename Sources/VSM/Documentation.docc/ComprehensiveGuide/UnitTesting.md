# Unit Testing a VSM Feature

A guide to writing unit tests that validate requirements in VSM features

## Overview

The type safety of the VSM architecture pattern prevents several categories of bugs from being introduced into the feature code. Despite this, there is still a chance that an engineer did not correctly implement the view state progression as described in the feature requirements.

Unit tests provide additional peace of mind that the engineer implemented the feature correctly. Unit tests also provide a safeguard against future regressions.

## Mocking the Data Repositories

Your observable data repositories should be designed in such a way that they can be mocked for testing. Mocking is the act of substituting a fake version of a piece of code that can be injected into a test subject to support testing the test subject.

Mocks generally allow the code within the unit test to provide a fake implementation that supports the unit test subject and prevents the unit test from accessing any ancillary resources that are not pertinent to the test. There are three common ways to design your data repositories to be mockable: protocols, structs with injectable implementations, or "stubs" that let you override certain aspects of the repository's behavior.

> Tip: Mocks should **_never_** include any business logic of any kind. They are purely [inversion-of-control](https://en.wikipedia.org/wiki/Inversion_of_control) types which exist solely to isolate a test subject from the implementation code of its dependencies while in a unit test.

### Mocking with Protocols

The most common form of designing for mockable testing is to use protocols that expose the properties and functions of the repository which are to be used broadly. Reference these repositories by protocol instead of their concrete type. This allows you to create special mock implementations of the repository which can be injected into the test subject while unit testing.

A protocol and its accompanying mock type may look like this:

```swift
protocol UserDataProviding {
    func load() -> AnyPublisher<UserData, Error>
}

struct MockUserDataProviding: UserDataProviding {
    var loadResult: AnyPublisher<UserData, Error>?
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
    let subject = LoaderModel(repository: mockRepository)
    let output = subject.load()
    let testExpectation = XCTestExpectation(description: "Load Publisher")
    var results: [LoadUserProfileViewState] = []
    output.sink { result in
        testExpectation.fulfill()
    } receiveValue: { value in
        results.append(value)
    }
    .store(in: &subscriptions)

    guard results.count > 0 else {
        XCTFail("Missing first state")
        return
    }

    let firstViewState = results[0]
    switch firstViewState {
    case .loading:
        break
    default:
        XCTFail("Expected loading state but got \(firstViewState)")
    }

    guard results.count > 1 else {
        XCTFail("Missing second state")
        return
    }

    let secondViewState = results[1]
    switch secondViewState {
    case .loaded(let userData):
        XCTAssertEqual(userData, expectedUserData)
    default:
        XCTFail("Expected loaded state but got \(secondViewState)")
    }
}
```

The above test calls the `LoaderModel`'s load function and asserts that the loading view state and the loaded state are emitted before the publisher finishes.

To consider the feature "fully tested", a test should be written for every model and action to validate that every possible view state output (including error states) is correctly emitted when called and that the appropriate data is associated with the view states.

> Tip: Be sure to use the ["Test Repeatedly"](https://www.avanderlee.com/debugging/flaky-tests-test-repetitions/) feature in Xcode to ensure that your Combine unit tests do not have flaky assertions.

## Easier Unit Testing

The above example is quite verbose. Fortunately, there are a few techniques that we can take advantage of to greatly reduce the volume of code required per unit test.

### Equatable View States

To more easily test a VSM feature, it is recommended that you conform your view state type to the `Equatable` protocol, even if just within your unit test target. This will allow you to compare states by simply using the XCTest APIs, such as `XCTAssertEqual`.

An example view state implementation of `Equatable` will look something like this:

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

The `Equatable` conformance makes the unit test much more concise:

```swift
func testUserProfileLoad() throws {
    let expectedUserData = UserData(username: "test")
    let mockRepository = MockDataRepository(loadResult: Just(expectedUserData))
    let subject = LoaderModel(repository: mockRepository)
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

## Testing Combine Publishers

Combine publishers are notoriously difficult and verbose to test. This is because they are inherently asynchronous and guarantee no specific behavior by their type signature. A publisher may emit many results or none. A throwing publisher may finish with an error, or never finish at all. Finally, merged publishers may not emit values to subscribers in a predictable order.

As you can see from the unit test examples above, there is quite a bit of boilerplate code required to unit test a single publisher. Considering how many unit tests that will need to be written to validate the output of every action for a VSM feature, this can result in a _ton_ of verbose unit test code.

The good news is that there is a library called [Testable Combine Publishers](https://github.com/albertbori/TestableCombinePublishers) which allows you to write unit tests for Combine publishers with _significantly_ less code. Since many of your VSM actions will return publishers, it may be a good idea to import this library into your test targets.

The above unit test example, if written with Testable Combine Publishers, will end up being as simple as:

```swift
func testUserProfileLoad() throws {
    let expectedUserData = UserData(username: "test")
    let mockRepository = MockDataRepository(loadResult: Just(expectedUserData))
    let subject = LoaderModel(repository: mockRepository)
    subject.load()
        .collect(2)
        .expect([.loading, .loaded(expectedUserData)])
        .expectSuccess()
        .waitForExpectations(timeout: 10)
}
...
extension LoadUserProfileViewState: AutomaticallyEquatable { /* no-op */ }
```

> Tip: The [`AutomaticallyEquatable`](https://github.com/albertbori/TestableCombinePublishers#automaticallyequatable) protocol extension in the Testable Combine Publishers library automatically conforms any type to `Equatable`. It does this by using reflection to recursively compare all of the values and their members against each other for equality.
>
> `AutomaticallyEquatable` is a good alternative to writing your own `Equatable` implementation because it will never become stale with future code changes.
>
> Note, that it has some interesting limitations which you can read in the documentation, but is generally safe for unit testing common cases.

## Behavior-driven Development

[Behavior-driven Development](https://en.wikipedia.org/wiki/Behavior-driven_development) (BDD) and [Test-driven Development](https://en.wikipedia.org/wiki/Test-driven_development) (TDD) are techniques that begin feature development by writing intentionally-failing unit tests as part of the development process. For BDD, the tests are written using a language like [Gherkin](https://en.wikipedia.org/wiki/Cucumber_(software)) which is then automatically interpreted into test script actions.

VSM development shares some concepts with BDD in that you should deeply understand the requirements and convert those requirements into Swift types (ie, the "shape of the feature") before you can start implementing the view or the models. While BDD and TDD are not required by VSM, these techniques may be good options to consider.

If you decide to use BDD or TDD with VSM, these steps can help you get started:

1. Build the shape of the feature states (see <doc:StateDefinition>)
1. Build and mock the protocols for the data repositories that the feature requires
1. Write failing unit tests against the view states and model definitions
1. Once you are confident that your tests are correct, implement the view, models, and repositories that will ultimately make these tests pass

Use the above exercise as a way to discover any gaps or discrepancies in the requirements.

> Note: Building features with BDD and TDD has a non-trivial tradeoff that's worth consideration: You are starting with technical debt. Your tests will likely be incorrect and need to be changed as you refine the requirements, UI, and implementation details. It is up to your team to decide if this up-front cost is worth the investment.
>
> As you develop features in VSM, you may find the process of defining and refining the "shape of the feature" to be an acceptable alternative to fully adopting BDD or TDD.

## Conclusion

This concludes the <doc:ComprehensiveGuide>. For further reading, feel free to browse the VSM Reference articles or API documentation found in the <doc:VSM> document directory.

### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
