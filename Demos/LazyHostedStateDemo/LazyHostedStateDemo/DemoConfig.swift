//
//  DemoConfig.swift
//  LazyHostedStateDemo
//
//  Launch-argument configuration, so UI tests and profiling runs can pick a configuration
//  without touching the UI. Pass arguments in `-key value` form:
//
//    -mode baseline|hosted     where card state is owned (default: baseline)
//    -purge 0|1                simulate SwiftUI discarding row @State (default: 0)
//    -purgeInterval <seconds>  how often the simulated purge happens (default: 3)
//    -autoscroll 0|1           run the built-in scroll script on launch (default: 0)
//    -cycles <n>               number of down/up passes for -autoscroll (default: 3)
//    -UITesting                disable animations that would slow UI tests
//

import Foundation
import Observation

enum CardStateOwnership: String, CaseIterable, Identifiable {
    /// Cards use `@ViewState`: each row owns its container in SwiftUI `@State`.
    case baseline
    /// Cards use `@HostedViewState`: containers come from a `ViewStateStore` owned by the feed.
    case hosted

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct LaunchConfig: Sendable {
    var mode: CardStateOwnership = .baseline
    var purge = false
    var purgeInterval: TimeInterval = 3
    var autoscroll = false
    var cycles = 3
    var isUITesting = false

    static let current: LaunchConfig = {
        let defaults = UserDefaults.standard
        var config = LaunchConfig()
        if let raw = defaults.string(forKey: "mode"), let mode = CardStateOwnership(rawValue: raw) {
            config.mode = mode
        }
        config.purge = defaults.bool(forKey: "purge")
        if defaults.object(forKey: "purgeInterval") != nil {
            config.purgeInterval = max(0.5, defaults.double(forKey: "purgeInterval"))
        }
        config.autoscroll = defaults.bool(forKey: "autoscroll")
        if defaults.object(forKey: "cycles") != nil {
            config.cycles = max(1, defaults.integer(forKey: "cycles"))
        }
        config.isUITesting = CommandLine.arguments.contains("-UITesting")
        return config
    }()
}

/// Settings the on-screen controls change at runtime. Seeded from the launch arguments.
@MainActor
@Observable
final class DemoSettings {
    var mode: CardStateOwnership
    var purge: Bool
    let purgeInterval: TimeInterval
    let autoscroll: Bool
    let cycles: Int

    init(config: LaunchConfig = .current) {
        mode = config.mode
        purge = config.purge
        purgeInterval = config.purgeInterval
        autoscroll = config.autoscroll
        cycles = config.cycles
    }
}
