//
//  TestHelpers.swift
//  
//
//  Created by Albert Bori on 7/21/22.
//

import Combine
@testable import VSM
import XCTest

extension XCTestCase {
    func test(_ subject: StateContainer<MockState>,
              expect expected: [MockState],
              when action: (StateContainer<MockState>) -> Void,
              file: StaticString = #file,
              line: UInt = #line) {
        let test = subject.$state
            .collect(expected.count)
            .expect({ _ in XCTAssert(Thread.isMainThread, "Observed published-state action should sink on main thread.", file: file, line: line) }, file: file, line: line)
            .expect(expected, file: file, line: line)
        action(subject)
        test.waitForExpectations(timeout: 1)
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
