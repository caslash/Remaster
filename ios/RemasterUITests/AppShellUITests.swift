//
//  AppShellUITests.swift
//  RemasterUITests
//
//  The tab shell (RMSTR-58): Library and Upgrades tabs, and the scanner sheet
//  that ContentView presents. The Scan tab is gone; the scanner opens from
//  Library's + menu (Scan a Shelf) or the empty library's Scan a Shelf button,
//  both as the same sheet. The menu's Search by Title is covered in
//  TitleSearchUITests.
//
//  Launches with SIMULATED_SERVICES like the lookup tests, so nothing reaches a
//  backend. The Simulator has no camera scanner, so the sheet shows the manual
//  entry form in its place. Not covered yet:
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

    // MARK: AC 1: a tab bar with Library and Upgrades; the scanner opens from Library

    func testLaunchShowsTabsAndAddMenu() {
        app.launch()

        XCTAssertTrue(tab(.library).waitForExistence(timeout: 10), "Library tab is missing")
        XCTAssertTrue(tab(.upgrades).exists, "Upgrades tab is missing")
        XCTAssertTrue(addNew.waitForExistence(timeout: 5), "Library's + button is missing")
        XCTAssertFalse(app.buttons["Scan"].exists, "The Scan tab should be gone")
        XCTAssertTrue(waitUntilSelected(.library), "The app should open on Library")
        XCTAssertFalse(dismissScanner.exists, "The scanner shouldn't be open at launch")
    }

    // MARK: AC 2: the scanner opens as a sheet; closing returns to Library

    func testAddMenuOffersScanAndSearch() {
        app.launch()
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "+ is missing")

        addNew.tap()
        XCTAssertTrue(menuItem("Scan a Shelf").waitForExistence(timeout: 5), "The + menu has no Scan a Shelf")
        XCTAssertTrue(menuItem("Search by Title").exists, "The + menu has no Search by Title")
        XCTAssertFalse(dismissScanner.exists, "Tapping + opened the scanner instead of a menu")
    }

    func testAddMenuOpensTheScannerAndCloseReturnsToLibrary() {
        app.launch()
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "+ is missing")

        openScannerFromAddMenu()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")
        XCTAssertTrue(manualEntryField.exists, "The scanner sheet didn't show the manual entry form")

        dismissScanner.tap()
        XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        XCTAssertTrue(waitUntilSelected(.library), "Closing the scanner didn't return to Library")
    }

    func testScanAShelfOpensTheSameScanner() {
        app.launch()
        XCTAssertTrue(scanAShelf.waitForExistence(timeout: 10), "The empty library's Scan a Shelf button is missing")

        scanAShelf.tap()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scan a Shelf didn't open the scanner")
        XCTAssertTrue(manualEntryField.exists, "Scan a Shelf opened something other than the scanner sheet")

        dismissScanner.tap()
        XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        XCTAssertTrue(waitUntilSelected(.library), "Closing the scanner didn't return to Library")
    }

    func testScannerCanBeOpenedAgainAfterClosing() {
        app.launch()
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "+ is missing")

        for fromMenu in [true, false, true] {
            if fromMenu { openScannerFromAddMenu() } else { scanAShelf.tap() }
            XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open from \(fromMenu ? "the + menu" : "Scan a Shelf")")
            dismissScanner.tap()
            XCTAssertTrue(dismissScanner.waitForNonExistence(timeout: 5), "Scanner didn't close")
        }
    }

    // MARK: Privacy: navigation alone makes no requests

    func testOpeningTheScannerDoesNotStartALookup() {
        app.launch()
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "+ is missing")

        openScannerFromAddMenu()
        XCTAssertTrue(dismissScanner.waitForExistence(timeout: 5), "Scanner didn't open")

        XCTAssertFalse(app.activityIndicators["page.scanning.progress"].exists, "Opening the scanner started a lookup")
        XCTAssertFalse(app.staticTexts["page.confirm.title"].exists, "Opening the scanner showed an edition sheet")
        XCTAssertEqual(app.alerts.count, 0, "Opening the scanner showed a lookup result")
    }

    // MARK: AC 5: reachable and labelled at the largest accessibility size

    func testTabsAndScannerAreReachableAtLargestTextSize() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        XCTAssertTrue(tab(.library).waitForExistence(timeout: 10), "Library tab is missing")
        XCTAssertTrue(addNew.waitForExistence(timeout: 5), "+ is missing")
        for element in [tab(.library), tab(.upgrades), addNew] {
            XCTAssertTrue(element.isHittable, "\(element) isn't reachable at the largest text size")
            XCTAssertFalse(element.label.isEmpty, "\(element) has no VoiceOver label")
        }

        tab(.upgrades).tap()
        XCTAssertTrue(waitUntilSelected(.upgrades), "Tapping Upgrades didn't select it at the largest text size")

        tab(.library).tap()
        XCTAssertTrue(waitUntilSelected(.library), "Tapping Library didn't select it at the largest text size")

        openScannerFromAddMenu()
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

    /// Library's + toolbar menu. Matched by label: "Add new", or "Add", which is
    /// what VoiceOver reads for a bare + image.
    private var addNew: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN {'Add new', 'Add'}")).firstMatch
    }

    /// An item in the open + menu. Looked up inside the menu's collection view so
    /// it isn't confused with the empty library's button of the same name.
    private func menuItem(_ label: String) -> XCUIElement {
        app.collectionViews.buttons[label].firstMatch
    }

    private func openScannerFromAddMenu(file: StaticString = #filePath, line: UInt = #line) {
        addNew.tap()
        let scan = menuItem("Scan a Shelf")
        XCTAssertTrue(scan.waitForExistence(timeout: 5), "The + menu has no Scan a Shelf", file: file, line: line)
        scan.tap()
    }

    /// The empty library's primary button (not the + menu's item).
    private var scanAShelf: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Scan a Shelf' AND identifier == ''")).firstMatch
    }

    private var manualEntryField: XCUIElement {
        app.textFields["page.scanning.manualEntry.field"]
    }

    /// The scanner's Close button. In the Simulator the sheet shows the manual entry
    /// form, whose Close has its own identifier, so match either one or the label.
    private var dismissScanner: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier IN {'page.scanning.dismiss', 'page.scanning.manualEntry.dismiss'} OR label == 'Close'")).firstMatch
    }
}
