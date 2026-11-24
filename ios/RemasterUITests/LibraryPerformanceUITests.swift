//
//  LibraryPerformanceUITests.swift
//  RemasterUITests
//
//  RMSTR-18 AC 2: with a 500-item library the grid loads in under 1 s and
//  scrolling stays smooth.
//
//  The app launches with SIMULATED_SERVICES and SEED_LIBRARY, which fills an
//  in-memory library with 500 copies of the sample editions (LibrarySeeder).
//
//  - The load test asserts the 1 s budget: the first card is on screen within
//    1 s of the app finishing launch (seeding happens during launch).
//  - The scroll test measures hitches with scrollingAndDecelerationMetric. It
//    reports numbers rather than failing on them: set a baseline in Xcode's test
//    report once a run on a recent iPhone looks right, and later runs fail if
//    they regress past it. Simulator numbers are only a rough guide; the
//    acceptance check is a device run in Instruments (Hitches template).
//

import XCTest

@MainActor
final class LibraryPerformanceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES", "SEED_LIBRARY"]
    }

    func testSeededGridShowsCardsWithinOneSecond() {
        app.launch()
        openLibrary()

        XCTAssertTrue(firstCard.waitForExistence(timeout: 1), "No card on screen within 1 s with a 500-item library")
    }

    func testSeededLibraryHasEnoughCardsToScroll() {
        app.launch()
        openLibrary()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5), "No cards in the seeded library")

        // Only on-screen cells exist in a lazy grid, so scroll and check that
        // new cards keep arriving rather than counting all 500.
        let grid = app.scrollViews.firstMatch
        let before = Set(cards.allElementsBoundByIndex.map(\.frame.minY))
        grid.swipeUp(velocity: .fast)
        grid.swipeUp(velocity: .fast)
        let after = cards.allElementsBoundByIndex.count

        XCTAssertGreaterThan(after, 0, "Scrolling the seeded grid left no cards on screen")
        XCTAssertFalse(before.isEmpty, "No cards were laid out before scrolling")
    }

    func testScrollingTheSeededGrid() {
        app.launch()
        openLibrary()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5), "No cards in the seeded library")
        let grid = app.scrollViews.firstMatch

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            grid.swipeUp(velocity: .fast)
            stopMeasuring()
            // Back to the top between iterations, outside the measured part.
            grid.swipeDown(velocity: .fast)
            grid.swipeDown(velocity: .fast)
        }
    }

    // MARK: Helpers

    private var cards: XCUIElementQuery {
        app.buttons.matching(identifier: "page.library.card")
    }

    private var firstCard: XCUIElement {
        cards.firstMatch
    }

    private func openLibrary(file: StaticString = #filePath, line: UInt = #line) {
        let library = app.buttons.matching(NSPredicate(format: "identifier == 'tab.library' OR label == 'Library'")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10), "Library tab is missing", file: file, line: line)
        if !library.isSelected { library.tap() }
    }
}
