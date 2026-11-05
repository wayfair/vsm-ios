//
//  DebugOverlay.swift
//  LazyHostedStateDemo
//

import SwiftUI

/// Shows the counters that matter for this experiment. The store count comes from the feed's
/// ViewStateStore; the fetch counters come from the mock repository.
struct DebugOverlay: View {
    let mode: CardStateOwnership
    let storeCount: @MainActor () -> Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let metrics = DemoMetrics.shared.snapshot
            HStack(spacing: 12) {
                Text(mode == .hosted ? "Store: \(storeCount())" : "Store: n/a")
                    .accessibilityIdentifier("overlay-store-count")
                Text("Started: \(metrics.detailFetchesStarted)")
                    .accessibilityIdentifier("overlay-started")
                Text("Cancelled: \(metrics.detailFetchesCancelled)")
                    .accessibilityIdentifier("overlay-cancelled")
            }
            .font(.caption.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: .capsule)
            .padding(.bottom, 8)
        }
    }
}
