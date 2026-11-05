//
//  DemoMetrics.swift
//  LazyHostedStateDemo
//
//  Counters kept in the mock repository so both modes are measured identically.
//

import Foundation
import os

final class DemoMetrics: Sendable {
    static let shared = DemoMetrics()

    struct Snapshot: Codable, Sendable, Equatable {
        var detailFetchesStarted = 0
        var detailFetchesCompleted = 0
        var detailFetchesCancelled = 0
    }

    private let storage = OSAllocatedUnfairLock(initialState: Snapshot())

    var snapshot: Snapshot { storage.withLock { $0 } }

    func fetchStarted() { storage.withLock { $0.detailFetchesStarted += 1 } }
    func fetchCompleted() { storage.withLock { $0.detailFetchesCompleted += 1 } }
    func fetchCancelled() { storage.withLock { $0.detailFetchesCancelled += 1 } }
    func reset() { storage.withLock { $0 = Snapshot() } }
}

/// Writes machine-readable run results into the app's Documents directory, so profiling scripts can
/// tell when the scroll script finished and read the counters without screen scraping.
enum RunReport {
    struct Report: Codable {
        var mode: String
        var purge: Bool
        var storeCount: Int
        var totalProducts: Int
        var metrics: DemoMetrics.Snapshot
    }

    static func write(named name: String, _ report: Report) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
