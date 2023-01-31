//
//  StateContainer+Debug.swift
//  This file provides `StateContainer.$state` debugging logging behavior when compiling in DEBUG configurations
//
//  Created by Albert Bori on 5/12/22.
//

#if DEBUG

import Combine
import Foundation

public extension StateContaining {
    
    /// Prints all state changes in this `StateContainer`, starting with the current state. ⚠️ Requires DEBUG configuration.
    @available(*, deprecated, message: "This debug statement only compiles in DEBUG schemas.")
    @discardableResult
    func _debug(options: _StateContainerDebugOptions = .defaults) -> Self {
        if let stateContainer = self as? StateContainer<State> {
            stateContainer.debugLogger.startLogging(for: stateContainer, options: options)
        }
        return self
    }
}

public extension StateContaining where State == Any {
    
    /// Prints all state changes in every `StateContainer` created after this line. ⚠️ Requires DEBUG configuration.
    @available(*, deprecated, message: "This debug statement only compiles in DEBUG schemas.")
    static func _debug(options: _StateContainerDebugOptions = .defaults) {
        StateContainerDebugLogger.defaultLoggingModes = options
    }
}

#endif

extension StateContainer {
    func registerForDebugLogging() {
#if DEBUG
        if !StateContainerDebugLogger.defaultLoggingModes.isEmpty {
            debugLogger.startLogging(for: self, options: StateContainerDebugLogger.defaultLoggingModes)
        }
#endif
    }
}

/// Manages debug logging for a state container
class StateContainerDebugLogger {
    static var defaultLoggingModes: _StateContainerDebugOptions = []
    private lazy var subscriptions: [_StateContainerDebugOptions: AnyCancellable] = [:]
        
    private struct Event<State> {
        let name: String
        let state: State
        let description: String
    }
    
    /// Registers debug logging once per mode per state container (to prevent duplicate logging from multiple calls)
    func startLogging<State>(for container: StateContainer<State>, options: _StateContainerDebugOptions) {
        guard subscriptions[options] == nil else { return }
        
        let memoryAddress = "[\(Unmanaged.passUnretained(container).toOpaque())]"
        let containerType = "\(type(of: container))"
        var publisher: AnyPublisher<Event, Never> = Empty<Event<State>, Never>().eraseToAnyPublisher()
        
        if options.contains(.willSet) {
            publisher = publisher
                .merge(with: container.$state
                    .map({ .init(name: "willSet", state: $0, description: "\($0)") }))
                .eraseToAnyPublisher()
        }
        if options.contains(.didSet) {
            publisher = publisher
                .merge(with: container.publisher
                    .map({ .init(name: "didSet", state: $0, description: "\($0)") }))
                .eraseToAnyPublisher()
        }
        
        subscriptions[options] = publisher
            .sink { event in
                var logParts: [String] = []
                if options.contains(.memory) {
                    logParts.append(memoryAddress)
                }
                if options.contains(.container) {
                    logParts.append(containerType)
                }
                if options.contains(.event) {
                    logParts.append(event.name)
                }
                if options.contains(.enumLabel) {
                    logParts.append(_StateContainerUtils.getEnumName(event.state))
                } else {
                    logParts.append(event.description)
                }
                if options.contains(.print) {
                    print(logParts.joined(separator: " "))
                }
                if options.contains(.nsLog) {
                    NSLog(logParts.joined(separator: " "))
                }
            }
    }
}

public struct _StateContainerDebugOptions: OptionSet, Hashable {
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Logs when the state will be set
    public static let willSet   = _StateContainerDebugOptions(rawValue: 1 << 0)
    /// Logs when the state has been set
    public static let didSet    = _StateContainerDebugOptions(rawValue: 1 << 1)
    /// Use the print function for emitting the log to the console
    public static let print     = _StateContainerDebugOptions(rawValue: 1 << 2)
    /// Use the NSLog function for emitting the log to the console
    public static let nsLog     = _StateContainerDebugOptions(rawValue: 1 << 3)
    /// Includes the memory address of the state container
    public static let memory    = _StateContainerDebugOptions(rawValue: 1 << 4)
    /// Includes the state container name
    public static let container = _StateContainerDebugOptions(rawValue: 1 << 5)
    /// Includes the event name
    public static let event     = _StateContainerDebugOptions(rawValue: 1 << 6)
    /// Prints only the name of the enum value
    public static let enumLabel = _StateContainerDebugOptions(rawValue: 1 << 7)
    
    /// `[.didSet, .print]`
    public static let defaults: Self = [.didSet, .print, .memory, .container, .event]
    public static let enumDefaults: Self = [.didSet, .print, .memory, .container, .event, .enumLabel]
    public static let conciseEnum: Self = [.didSet, .print, .enumLabel]
}

public enum _StateContainerUtils {
    public static func getEnumName(_ subject: Any) -> String {
        let mirror = Mirror(reflecting: subject)
        return mirror.children.first?.label ?? "\(subject)"
    }
}
