//
//  FrameMonitor.swift
//  LazyHostedStateDemo
//
//  In-app frame pacing, because the Animation Hitches instrument is not available on the simulator.
//  Counts frames that took noticeably longer than the display's frame budget. Directional only:
//  the simulator renders on the Mac's GPU and its timing is not representative of a device.
//

import QuartzCore
import UIKit

@MainActor
final class FrameMonitor {
    struct Result: Codable {
        var frames = 0
        var durationSeconds = 0.0
        /// Frames that took more than 1.5x the frame budget.
        var hitchFrames = 0
        /// Total time over budget in those frames, divided by total duration (like Apple's hitch time ratio).
        var hitchTimeRatioMsPerSec = 0.0
        /// Longest gap between two frames, in milliseconds. Gaps over 250 ms count as hangs.
        var maxFrameGapMs = 0.0
        var hangs = 0
    }

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var firstTimestamp: CFTimeInterval = 0
    private var overBudget = 0.0
    private var result = Result()

    func start() {
        stop()
        result = Result()
        overBudget = 0
        last = 0
        let link = CADisplayLink(target: Trampoline { [weak self] link in self?.tick(link) }, selector: #selector(Trampoline.fire(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func finish() -> Result {
        stop()
        guard last > firstTimestamp else { return result }
        result.durationSeconds = last - firstTimestamp
        result.hitchTimeRatioMsPerSec = result.durationSeconds > 0 ? overBudget * 1000 / result.durationSeconds : 0
        return result
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { last = now }
        guard last > 0 else { firstTimestamp = now; return }
        let gap = now - last
        let budget = link.targetTimestamp - link.timestamp
        result.frames += 1
        result.maxFrameGapMs = max(result.maxFrameGapMs, gap * 1000)
        if gap > budget * 1.5 {
            result.hitchFrames += 1
            overBudget += gap - budget
        }
        if gap > 0.25 { result.hangs += 1 }
    }

    private final class Trampoline: NSObject {
        let handler: (CADisplayLink) -> Void
        init(_ handler: @escaping (CADisplayLink) -> Void) { self.handler = handler }
        @objc func fire(_ link: CADisplayLink) { handler(link) }
    }
}
