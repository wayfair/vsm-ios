//
//  ScrollScriptUITests.swift
//  LazyHostedStateDemoUITests
//
//  A repeatable scroll script: fast-swipe down through the feed, back to the top, and down again.
//

import XCTest

@MainActor
final class ScrollScriptUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(mode: String, purge: Bool, purgeInterval: Int = 2) {
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-mode", mode,
            "-purge", purge ? "1" : "0",
            "-purgeInterval", String(purgeInterval),
        ]
        app.launch()
    }

    private func favorite(_ id: String) -> XCUIElement { app.buttons["favorite-\(id)"] }

    private func waitForLoadedCard(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(favorite(id).waitForExistence(timeout: 15), "\(id) should finish loading", file: file, line: line)
    }

    /// Fast swipes down, then back up to the top, `cycles` times. Ends at the top.
    private func runScrollScript(cycles: Int, swipesPerPass: Int = 12) {
        let feed = app.scrollViews["feed-scroll"]
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        for _ in 0..<cycles {
            for _ in 0..<swipesPerPass { feed.swipeUp(velocity: .fast) }
            for _ in 0..<swipesPerPass { feed.swipeDown(velocity: .fast) }
            for _ in 0..<3 { feed.swipeDown(velocity: .fast) } // make sure we are at the top
        }
    }

    private func overlayCount(_ id: String) -> Int {
        let label = app.staticTexts[id].label
        return Int(label.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? -1
    }

    // MARK: - Tests

    func testHostedKeepsFavoritesAfterScrolling() {
        launch(mode: "hosted", purge: false)
        let ids = ["SKU-1", "SKU-2", "SKU-3"]
        ids.forEach { waitForLoadedCard($0) }
        ids.forEach { favorite($0).tap() }
        ids.forEach {
            XCTAssertEqual(favorite($0).label, "Remove from favorites", "\($0) should be favorited before scrolling")
        }

        runScrollScript(cycles: 3)

        ids.forEach {
            XCTAssertTrue(favorite($0).waitForExistence(timeout: 5), "\($0) should be back on screen")
            XCTAssertEqual(favorite($0).label, "Remove from favorites", "\($0) should still be favorited")
        }
        XCTAssertGreaterThan(overlayCount("overlay-store-count"), 0, "Hosted mode should be retaining containers")
    }

    func testHostedKeepsFavoritesWithSimulatedPurge() {
        launch(mode: "hosted", purge: true, purgeInterval: 2)
        let ids = ["SKU-1", "SKU-2", "SKU-3"]
        ids.forEach { waitForLoadedCard($0) }
        ids.forEach { favorite($0).tap() }

        runScrollScript(cycles: 3) // takes long enough for several purge generations

        ids.forEach {
            XCTAssertTrue(favorite($0).waitForExistence(timeout: 5))
            XCTAssertEqual(favorite($0).label, "Remove from favorites", "\($0) should survive rebuilt rows")
        }
    }

    func testBaselineLosesFavoritesWithSimulatedPurge() {
        launch(mode: "baseline", purge: true, purgeInterval: 2)
        waitForLoadedCard("SKU-1")
        favorite("SKU-1").tap()
        XCTAssertEqual(favorite("SKU-1").label, "Remove from favorites")

        // After the next purge the row is rebuilt, its @State is gone, and it refetches as not favorited.
        let predicate = NSPredicate(format: "label == %@", "Add to favorites")
        let reset = expectation(for: predicate, evaluatedWith: favorite("SKU-1"))
        wait(for: [reset], timeout: 15)
    }

    func testBaselineRefetchesMoreThanHostedWithSimulatedPurge() {
        launch(mode: "baseline", purge: true, purgeInterval: 2)
        runScrollScript(cycles: 1, swipesPerPass: 6)
        let baselineStarted = overlayCount("overlay-started")
        app.terminate()

        launch(mode: "hosted", purge: true, purgeInterval: 2)
        runScrollScript(cycles: 1, swipesPerPass: 6)
        let hostedStarted = overlayCount("overlay-started")

        XCTAssertGreaterThan(baselineStarted, 0)
        XCTAssertGreaterThan(baselineStarted, hostedStarted, "Baseline should start more detail fetches than Hosted")
    }
}
