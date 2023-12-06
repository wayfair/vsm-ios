//
//  MutatingCopyableTests.swift
//
//
//  Created by Albert Bori on 12/6/23.
//

@testable import VSM
import XCTest

final class MutatingCopyableTests: XCTestCase {
    struct Subject: MutatingCopyable {
        var bar: String
        var baz: Bool
    }
    
    func testMutatingCopyableClosure() {
        let subject = Subject(bar: "old", baz: false)
        let result = subject.copy {
            $0.bar = "new"
            $0.baz = true
        }
        XCTAssertEqual(result.bar, "new")
        XCTAssertEqual(result.baz, true)
    }
    
    func testMutatingCopyableKeyPath() {
        let subject = Subject(bar: "old", baz: false)
        let result = subject
            .copy(mutatingPath: \.bar, value: "new")
            .copy(mutatingPath: \.baz, value: true)
        XCTAssertEqual(result.bar, "new")
        XCTAssertEqual(result.baz, true)
    }
}
