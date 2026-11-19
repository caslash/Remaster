//
//  AppShellUITests.swift
//  RemasterUITests
//
//  The tab shell: Library, Upgrades and the Scan action (RMSTR-58).
//
//  Launches with SIMULATED_SERVICES like the lookup tests, so nothing reaches a
//  backend. Not covered yet:
//  - AC 3, the Upgrades badge: it's fixed at 0 (hidden) until RMSTR-29 wires up
//    the count.
//  - AC 4, per-tab scroll position and navigation stack: the placeholder tabs
//    have nothing to scroll or push yet. Add once RMSTR-18 and RMSTR-29 land.
//

import XCTest

@MainActor
final class AppShellUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES"]
    }

    // MARK: AC 1: a tab bar with Library and Upgrades, and a Scan action

    func testLaunchShowsTabsAndScan() {
        app.launch()

        XCTAssertTrue(tab(.library).waitForExistence(timeout: 10), "Library tab is missing")
        XCTAssertTrue(tab(.upgrades).exists, "Upgrades tab is missing")
        XCTAssertTrue(scanAction.exists, "Scan action is missing")
        XCTAssertTrue(waitUntilSelected(.library), "The app should open on Library")
        XCTAssertFalse(dismissScanner.exists, "The scanner shouldn't be open at launch")
    }

    // MARK: AC 2: Scan opens the scanner; closing returns to the tab I was on

    func testScanOpensScannerAndCloseReturnsToLibrary() {
        app.launch()
        XCTAssertTrue(scanAction.waitForExistence(timeout: 10), "Scan action is missing")

        scanAction.tap()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")

        dismissScanner.tap()
        XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        XCTAssertTrue(waitUntilSelected(.library), "Closing the scanner didn't return to Library")
    }

    func testCloseReturnsToUpgradesWhenOpenedFromUpgrades() {
        app.launch()
        XCTAssertTrue(tab(.upgrades).waitForExistence(timeout: 10), "Upgrades tab is missing")
        tab(.upgrades).tap()
        XCTAssertTrue(waitUntilSelected(.upgrades), "Tapping Upgrades didn't select it")

        scanAction.tap()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")

        dismissScanner.tap()
        XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        XCTAssertTrue(waitUntilSelected(.upgrades), "Closing the scanner didn't return to Upgrades")
        XCTAssertFalse(tab(.library).isSelected, "Library is selected after closing the scanner opened from Upgrades")
    }

    func testScanCanBeOpenedAgainAfterClosing() {
        app.launch()
        XCTAssertTrue(scanAction.waitForExistence(timeout: 10), "Scan action is missing")

        for _ in 0..<2 {
            scanAction.tap()
            XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")
            dismissScanner.tap()
            XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        }
    }

    // MARK: Privacy: navigation alone makes no requests

    func testOpeningScanDoesNotStartALookup() {
        app.launch()
        XCTAssertTrue(scanAction.waitForExistence(timeout: 10), "Scan action is missing")

        scanAction.tap()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")

        XCTAssertFalse(app.activityIndicators["page.scanning.progress"].exists, "Opening Scan started a lookup")
        XCTAssertFalse(app.sheets.firstMatch.exists, "Opening Scan showed an edition sheet")
        XCTAssertEqual(app.alerts.count, 0, "Opening Scan showed a lookup result")
    }

    // MARK: AC 5: reachable and labelled at the largest accessibility size

    func testTabsAndScanAreReachableAtLargestTextSize() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(tab(.library).waitForExistence(timeout: 10), "Library tab is missing")
        for element in [tab(.library), tab(.upgrades), scanAction] {
            XCTAssertTrue(element.isHittable, "\(element) isn't reachable at the largest text size")
            XCTAssertFalse(element.label.isEmpty, "\(element) has no VoiceOver label")
        }

        tab(.upgrades).tap()
        XCTAssertTrue(waitUntilSelected(.upgrades), "Tapping Upgrades didn't select it at the largest text size")

        scanAction.tap()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open at the largest text size")
        XCTAssertTrue(dismissScanner.isHittable, "Close isn't reachable at the largest text size")
        XCTAssertFalse(dismissScanner.label.isEmpty, "Close has no VoiceOver label")
    }

    // MARK: Helpers

    private enum ShellTab: String {
        case library = "Library"
        case upgrades = "Upgrades"

        var identifier: String { "tab.\(rawValue.lowercased())" }
    }

    /// Not looked up through `app.tabBars`: on iPhone Duo the tabs sit in a vertical
    /// bar that isn't exposed as a TabBar. Matched by identifier or label, because
    /// iOS 27.0 doesn't expose the `tab.*` identifiers and 27.1 does.
    private func tab(_ tab: ShellTab) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", tab.identifier, tab.rawValue)).firstMatch
    }

    /// Selection can lag a tap or a dismissal by a frame or two, so wait for it.
    private func waitUntilSelected(_ tab: ShellTab, timeout: TimeInterval = 5) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self.tab(tab))
        return XCTWaiter.wait(for: [selected], timeout: timeout) == .completed
    }

    private var scanAction: XCUIElement {
        app.buttons["Scan"].firstMatch
    }

    /// The scanner's Close button: by its identifier if it has one, otherwise its label.
    private var dismissScanner: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'page.scanning.dismiss' OR label == 'Close'")).firstMatch
    }
}
