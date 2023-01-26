//
//  ViewStateRenderingTests+ObserveDebounce.swift
//  
//
//  Created by Albert Bori on 6/24/22.
//

import Combine
@testable import VSM
import XCTest

@available(macOS 12, *)
class ViewStateRenderingTests_ObserveDebounce: XCTestCase {
    var subject: AnyViewStateRendering<MockState>!
    var cancellables: Set<AnyCancellable> = []
    var countableAction: CountablePublisherAction<MockState>!
    var actionCallSite: (() -> Void)!

    override func setUpWithError() throws {
        subject = AnyViewStateRendering(container: .init(state: .foo))
        countableAction = CountablePublisherAction<MockState> {
            Just(.bar).eraseToAnyPublisher()
        }
        actionCallSite = {
            self.subject.observe(self.countableAction.invoke(), debounced: .seconds(0.5))
        }
    }
    
    override func tearDownWithError() throws {
        subject = nil
        cancellables.forEach { $0.cancel() }
        cancellables = []
    }
    
    /// Asserts that multiple immediate action observations will only execute once
    func testDebounce_DefaultId_SingleAction_Immediate() async throws {
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Asserts that multiple time-delayed action observations will only execute once if both happen within the debounce delay
    func testDebounce_DefaultId_SingleAction_Delayed_SingleCall() async throws {
        actionCallSite()
        try await Task.sleep(seconds: 0.2)
        actionCallSite()
        try await Task.sleep(seconds: 0.8) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Asserts that multiple time-delayed action observations will each execute, if they are called far enough apart
    func testDebounce_DefaultId_SingleAction_Delayed_MultipleCalls() async throws {
        actionCallSite()
        try await Task.sleep(seconds: 0.6)
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(2, countableAction.count)
    }
    
    /// Asserts that multiple action observations in different places will not debounce together. (default id identifies by call-site)
    /// Regardless if the action is the same memory location, because actions are not equatable
    func testDebounce_DefaultId_MultipleAction_Immediate_MultipleCalls() async throws {
        let actionCallSite2: () -> Void = {
            self.subject.observe(self.countableAction.invoke(), debounced: .seconds(0.5))
        }
        actionCallSite()
        actionCallSite2()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(2, countableAction.count)
    }
    
    /// Asserts that multiple action observations in different places will debounce together when using the same identifier
    func testDebounce_CustomId_MultipleAction_Immediate_SingleCall() async throws {
        let id = "some_id"
        let countableAction1 = CountablePublisherAction<MockState> {
            Just(.bar).eraseToAnyPublisher()
        }
        let actionCallSite1: () -> Void = {
            self.subject.observe(countableAction1.invoke(), debounced: .seconds(0.5), identifier: id)
        }
        let countableAction2 = CountablePublisherAction<MockState> {
            Just(.baz).eraseToAnyPublisher()
        }
        let actionCallSite2: () -> Void = {
            self.subject.observe(countableAction2.invoke(), debounced: .seconds(0.5), identifier: id)
        }
        actionCallSite1()
        actionCallSite2()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(0, countableAction1.count)
        XCTAssertEqual(1, countableAction2.count)
    }
    
    /// Asserts that multiple immediate action observations will only execute once and won't crash when invoked at the same time from different threads
    func testDebounce_ThreadSafety() async throws {
        for _ in 1...10 {
            DispatchQueue.global().async {
                self.actionCallSite()
            }
        }
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the asyncrhonous debounce action overloads
    func testDebounce_AsyncOverload_DefaultId() async throws {
        let countableAction = CountableAsyncAction<MockState> {
            .bar
        }
        let actionCallSite: () -> Void = {
            self.subject.observe({ await countableAction.invoke() }, debounced: .seconds(0.5))
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the asyncrhonous debounce action overloads
    func testDebounce_AsyncOverload_CustomId() async throws {
        let countableAction = CountableAsyncAction<MockState> {
            .bar
        }
        let actionCallSite: () -> Void = {
            self.subject.observe(async: { await countableAction.invoke() }, debounced: .seconds(0.5), identifier: "some_id")
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the asyncrhonous sequence debounce action overloads
    func testDebounce_AsyncSequenceOverload_DefaultId() async throws {
        let countableAction = CountableAsyncSequenceAction<StateSequence<MockState>> {
            .init({ .bar })
        }
        let actionCallSite: () -> Void = {
            self.subject.observe({ await countableAction.invoke() }, debounced: .seconds(0.5))
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the asyncrhonous sequence debounce action overloads
    func testDebounce_AsyncSequenceOverload_CustomId() async throws {
        let countableAction = CountableAsyncSequenceAction<StateSequence<MockState>> {
            .init({ .bar })
        }
        let actionCallSite: () -> Void = {
            self.subject.observe(async: { await countableAction.invoke() }, debounced: .seconds(0.5), identifier: "some_id")
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the syncrhonous debounce action overloads
    func testDebounce_SynchronousOverload_DefaultId() async throws {
        let countableAction = CountableSynchronousAction<MockState> {
            .bar
        }
        let actionCallSite: () -> Void = {
            self.subject.observe(countableAction.invoke(), debounced: .seconds(0.5))
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
    
    /// Tests the syncrhonous debounce action overloads
    func testDebounce_SynchronousOverload_CustomId() async throws {
        let countableAction = CountableSynchronousAction<MockState> {
            .bar
        }
        let actionCallSite: () -> Void = {
            self.subject.observe(countableAction.invoke(), debounced: .seconds(0.5), identifier: "some_id")
        }
        
        actionCallSite()
        actionCallSite()
        actionCallSite()
        try await Task.sleep(seconds: 1) // wait for debounce timeout
        
        XCTAssertEqual(1, countableAction.count)
    }
}


// MARK: - Helpers

class Countable {
    private var threadQueue = DispatchQueue(label: "Countable", qos: .userInitiated)
    private var _count: Int = 0
    private(set) var count: Int {
        get { threadQueue.sync { _count } }
        set { threadQueue.sync { _count = newValue } }
    }
    
    func incrementCount() {
        count += 1
    }
}

class CountablePublisherAction<State>: Countable {
    private var _action: () -> AnyPublisher<State, Never>
    
    init(action: @escaping () -> AnyPublisher<State, Never>) {
        _action = action
    }
    
    func invoke() -> AnyPublisher<State, Never> {
        incrementCount()
        return _action()
    }
}

class CountableAsyncAction<State>: Countable {
    private var _action: () async -> State
    
    init(action: @escaping () async -> State) {
        _action = action
    }
    
    func invoke() async -> State {
        incrementCount()
        return await _action()
    }
}

class CountableAsyncSequenceAction<SomeAsyncSequence: AsyncSequence>: Countable {
    private var _action: () async -> SomeAsyncSequence
    
    init(action: @escaping () async -> SomeAsyncSequence) {
        _action = action
    }
    
    func invoke() async -> SomeAsyncSequence {
        incrementCount()
        return await _action()
    }
}

class CountableSynchronousAction<State>: Countable {
    private var _action: () -> State
    
    init(action: @escaping () -> State) {
        _action = action
    }
    
    func invoke() -> State {
        incrementCount()
        return _action()
    }
}
