//
//  XCTestCase+AwaitPublisher.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Combine
import Foundation
import XCTest

extension XCTestCase {
    /// Asserts that a single value is produced by the `Publisher` and that `receiveCompletion` is called.
    /// Adapted from https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
    /// - Returns: A single `Result` value produced by the `Publisher`.
    func waitForSingleValuePublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        handler: XCWaitCompletionHandler? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Result<T.Output, T.Failure> {
        var result: Result<T.Output, T.Failure>?
        let expectation = self.expectation(description: "Awaiting Publisher")

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    break
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                XCTAssertNil(result, "Awaited single-value Publisher produced more than one value.", file: file, line: line)
                result = .success(value)
            }
        )

        // Release cancellable and forward handler result
        waitForExpectations(timeout: timeout) { error in
            cancellable.cancel()
            handler?(error)
        }

        return try XCTUnwrap(result, "Awaited Publisher did not produce any output", file: file, line: line)
    }
    
    /// Asserts that 0...n values are produced by the `Publisher` and that `receiveCompletion` is called.
    /// Adapted from https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
    /// - Returns: All values in a `Result` produced by the `Publisher` in order of emition.
    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        handler: XCWaitCompletionHandler? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Result<[T.Output], T.Failure> {
        var result: Result<[T.Output], T.Failure>?
        var output: [T.Output] = []
        let expectation = self.expectation(description: "Awaiting Publisher")

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    result = .success(output)
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                output.append(value)
            }
        )

        // Release cancellable and forward handler result
        waitForExpectations(timeout: timeout) { error in
            cancellable.cancel()
            handler?(error)
        }

        return try XCTUnwrap(result, "Awaited Publisher did not produce any output", file: file, line: line)
    }
    
    /// Asserts that `expectedCount` values are produced by the `Publisher` regardless of whether`receiveCompletion` is called.
    /// Adapted from https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
    /// - Returns: `expectedCount` number of values in a `Result` produced by the `Publisher` in order of emition.
    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        expectedCount: Int,
        timeout: TimeInterval,
        handler: XCWaitCompletionHandler? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Result<[T.Output], T.Failure> {
        guard expectedCount >= 0 else {
            XCTFail("Invalid awaitPublisher expectedCount of \(expectedCount). Value must be 0 or greater.")
            throw AwaitPublisherError.invalidExpectedCount(expectedCount)
        }
        var result: Result<[T.Output], T.Failure>?
        var output: [T.Output] = []
        let expectation = self.expectation(description: "Awaiting Publisher")
        expectation.expectedFulfillmentCount = expectedCount

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    result = .success(output)
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                output.append(value)
                result = .success(output)
                expectation.fulfill()
            }
        )

        // Release cancellable and forward handler result
        waitForExpectations(timeout: timeout) { error in
            cancellable.cancel()
            handler?(error)
        }

        return try XCTUnwrap(result, "Awaited Publisher did not produce any output", file: file, line: line)
    }
    
    enum AwaitPublisherError: Error {
        case invalidExpectedCount(Int)
    }
}
