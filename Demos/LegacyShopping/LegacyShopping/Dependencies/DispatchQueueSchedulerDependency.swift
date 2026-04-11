//
//  DispatchQueueSchedulerDependency.swift
//  Shopping
//
//  Created by Albert Bori on 2/26/22.
//

import Combine
import Foundation
import CombineSchedulers

typealias AnyDispatchQueueScheduler = AnyScheduler<DispatchQueue.SchedulerTimeType, DispatchQueue.SchedulerOptions>

/// Provides existential `Scheduler`s for some `DispatchQueue`s to be used for managing timed actions.
/// This allows for controlling time while unit testing using `ImmediateScheduler`s
/// Scheduling convenience types are from https://github.com/pointfreeco/combine-schedulers
protocol DispatchQueueScheduling {
    var main: AnyDispatchQueueScheduler { get }
    var global: AnyDispatchQueueScheduler { get }
}

/// Provides existential `Scheduler`s for some `DispatchQueue`s to be used for managing timed actions.
/// This allows for controlling time while unit testing using `ImmediateScheduler`s
/// Scheduling convenience types are from https://github.com/pointfreeco/combine-schedulers
protocol DispatchQueueSchedulingDependency {
    var dispatchQueue: DispatchQueueScheduling { get }
}

class DispatchQueueScheduler: DispatchQueueScheduling {
    let main: AnyDispatchQueueScheduler = DispatchQueue.main.eraseToAnyScheduler()
    let global: AnyDispatchQueueScheduler = DispatchQueue.global().eraseToAnyScheduler()
}

class MockDispatchQueueScheduler: DispatchQueueScheduling {
    static var immediate: MockDispatchQueueScheduler {
        MockDispatchQueueScheduler(main: DispatchQueue.immediate.eraseToAnyScheduler(),
                                   global: DispatchQueue.immediate.eraseToAnyScheduler())
    }
    
    var main: AnyDispatchQueueScheduler
    var global: AnyDispatchQueueScheduler
    
    internal init(
        main: AnyDispatchQueueScheduler,
        global: AnyDispatchQueueScheduler
    ) {
        self.main = main
        self.global = global
    }
}
