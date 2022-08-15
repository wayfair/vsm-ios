//
//  MainViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Combine
import XCTest
@testable import Shopping

class MainViewStateTests: XCTestCase {
    
    /// Tests the loading state progression of the `DependenciesLoaderModel`
    func testLoad() throws {
        let mockedDependenciesProvider = AsyncResource<MainView.Dependencies>({ return MockAppDependencies.noOp })
        let subject = DependenciesLoaderModel(appDependenciesProvider: mockedDependenciesProvider)
        let output = try waitForPublisher(subject.loadDependencies(), expectedCount: 2, timeout: 1).get()
        if let firstOutput = output.first, case MainViewState.loading = firstOutput { } else {
            XCTFail("Expected first state of .loading, but got: \(output)")
        }
        if let lastOuput = output.last, case MainViewState.loaded = lastOuput { } else {
            XCTFail("Expected first state of .loading, but got: \(output)")
        }
    }

}
