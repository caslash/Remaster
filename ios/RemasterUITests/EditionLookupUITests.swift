//
//  EditionLookupUITests.swift
//  RemasterUITests
//
//  What the user sees after a lookup (RMSTR-11 AC 3, 4 and 5), and the confirm
//  sheet a found edition opens (RMSTR-14).
//
//  The app launches with SIMULATED_SERVICES, so SimulatedBarcodeService answers
//  from ios/Mocks/Editions.bundle and fakes errors for 000 (offline), 400, 404
//  and 503. The camera scanner isn't supported in the Simulator, so each test
//  opens Scan from the tab bar (RMSTR-58) and types the barcode into the manual
//  entry field that the scanning screen shows instead.
//

import XCTest

@MainActor
final class EditionLookupUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES"]
        app.launch()
    }

    // MARK: AC 3: the app shows the title and format

    // A found edition opens the confirm sheet (RMSTR-14) with the title and the
    // lookup's format already picked. The card shows the retail upcTitle, which
    // keeps the season or series scope that the TMDB name drops.
    func testFoundEditionShowsTitleAndFormat() {
        lookUp("786936900378")

        let title = app.staticTexts["page.confirm.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Confirm sheet didn't appear")
        XCTAssertEqual(title.label, "WandaVision: The Complete Series")
        XCTAssertTrue(formatSegment("4K UHD").isSelected, "The lookup's format isn't picked")
        XCTAssertTrue(app.buttons["page.confirm.add"].isEnabled, "Add to Library is disabled with a format picked")
    }

    // MARK: RMSTR-14: combo packs

    // WandaVision has two 4K discs, which is one format, not a combo pack.
    func testSingleFormatSetOffersNoComboToggle() {
        lookUp("786936900378")
        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForExistence(timeout: 5), "Confirm sheet didn't appear")

        XCTAssertFalse(comboToggle.exists, "Combo toggle shown for a single-format set")
    }

    // Hoppers is 4K + Blu-ray. The toggle offers the other format, and goes away
    // when the picked format isn't in the set.
    func testComboToggleFollowsThePickedFormat() {
        lookUp("043396648654")
        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForExistence(timeout: 5), "Confirm sheet didn't appear")

        XCTAssertTrue(comboToggle.exists, "Combo toggle missing for a 4K + Blu-ray set")
        XCTAssertTrue(comboToggle.label.contains("Also includes Blu-ray"), "Toggle offers the wrong format: \(comboToggle.label)")

        formatSegment("Blu-ray").tap()
        XCTAssertTrue(comboToggle.label.contains("Also includes 4K UHD"), "Toggle didn't follow the picker: \(comboToggle.label)")

        formatSegment("DVD").tap()
        XCTAssertFalse(comboToggle.exists, "Combo toggle shown for a format that isn't in the set")
    }

    // MARK: RMSTR-14: closing the sheet

    func testClosingConfirmReturnsToScanner() {
        lookUp("786936900378")
        let title = app.staticTexts["page.confirm.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Confirm sheet didn't appear")

        app.navigationBars["Is this right?"].buttons.firstMatch.tap()

        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Confirm sheet stayed up after Close")
        assertManualEntryIsReady()
    }

    // MARK: AC 4: not found shows a not-found message

    // A lookup typed into manual entry reports its failure under the field, not in
    // an alert, so the barcode can be corrected in place (RMSTR-16).
    func testNotFoundShowsMessageInline() {
        lookUp("404")

        assertInlineError("We don't know this disc yet")
        XCTAssertEqual(app.alerts.count, 0, "A manual lookup's failure raised an alert")
        assertManualEntryIsReady()
        XCTAssertEqual(manualEntryField.value as? String, "404", "The typed barcode was lost after a failed lookup")
    }

    // MARK: AC 5: a network or backend failure is retryable

    func testBackendFailureShowsMessageInline() {
        lookUp("503")

        assertInlineError("Remaster is having trouble")
        assertManualEntryIsReady()
    }

    func testOfflineShowsMessageInline() {
        lookUp("000")

        assertInlineError("You're offline")
        assertManualEntryIsReady()
    }

    // Look Up is the retry: the barcode is still in the field.
    func testLookingUpAgainRunsTheLookupAgain() {
        lookUp("503")
        assertInlineError("Remaster is having trouble")
        assertManualEntryIsReady()

        manualEntrySearch.tap()

        // The message goes away while the lookup runs, then the same failure brings it
        // back. The gap is only a few hundred milliseconds, shorter than
        // waitForNonExistence's polling interval, so check in a tight loop instead.
        XCTAssertTrue(disappears(inlineError, within: 5), "Error stayed up during the second lookup")
        assertInlineError("Remaster is having trouble")
    }

    // MARK: Bad scan (upc-endpoint.md: 400 means scan again, don't retry)

    func testBadBarcodeShowsMessageInline() {
        lookUp("400")

        assertInlineError("That's not a disc barcode")
        XCTAssertEqual(app.alerts.count, 0, "A manual lookup's failure raised an alert")
        assertManualEntryIsReady()
    }

    // A failed lookup followed by a good barcode clears the message and opens confirm.
    func testCorrectingTheBarcodeAfterAFailureFindsTheDisc() {
        lookUp("404")
        assertInlineError("We don't know this disc yet")
        assertManualEntryIsReady()

        manualEntryField.tap()
        manualEntryField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        manualEntryField.typeText("786936900378")
        manualEntrySearch.tap()

        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForExistence(timeout: 5), "Confirm sheet didn't appear")
    }

    // MARK: Manual entry is paused while a lookup runs

    func testManualEntryIsDisabledWhileLookingUp() {
        lookUp("503")

        // The simulated service waits at least MINIMUM_WAIT before answering, so the
        // field and button are still disabled right after Look Up.
        XCTAssertFalse(manualEntryField.isEnabled, "Manual entry stayed enabled during the lookup")
        XCTAssertFalse(manualEntrySearch.isEnabled, "Look Up stayed enabled during the lookup")
        assertInlineError("Remaster is having trouble")
    }

    // MARK: Helpers

    private var manualEntryField: XCUIElement {
        app.textFields["page.scanning.manualEntry.field"]
    }

    private var manualEntrySearch: XCUIElement {
        app.buttons["page.scanning.manualEntry.search"]
    }

    private var inlineError: XCUIElement {
        app.staticTexts["page.scanning.manualEntry.error"]
    }

    private func assertInlineError(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(inlineError.waitForExistence(timeout: 5), "Inline error didn't appear", file: file, line: line)
        XCTAssertEqual(inlineError.label, message, file: file, line: line)
        let suggestion = app.staticTexts["page.scanning.manualEntry.error.suggestion"]
        XCTAssertFalse(suggestion.label.contains("{"), "Raw JSON shown to the user: \(suggestion.label)", file: file, line: line)
    }

    private var comboToggle: XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Also includes'")).firstMatch
    }

    private func formatSegment(_ name: String) -> XCUIElement {
        app.segmentedControls["page.confirm.format"].buttons[name]
    }

    private func openScanner(file: StaticString = #filePath, line: UInt = #line) {
        let scan = app.buttons["Scan"].firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: 10), "Scan action didn't appear", file: file, line: line)
        scan.tap()
    }

    private func lookUp(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        openScanner(file: file, line: line)
        XCTAssertTrue(manualEntryField.waitForExistence(timeout: 5), "Manual entry field didn't appear", file: file, line: line)

        manualEntryField.tap()
        manualEntryField.typeText(barcode)
        manualEntrySearch.tap()
    }

    private func assertManualEntryIsReady(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(manualEntryField.waitForExistence(timeout: 5), "Manual entry field went away", file: file, line: line)
        let enabled = NSPredicate(format: "isEnabled == true")
        let ready = XCTNSPredicateExpectation(predicate: enabled, object: manualEntryField)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, "Manual entry didn't come back after dismissing", file: file, line: line)
    }

    private func disappears(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
        }
        return false
    }

    private func assertNoRawJSON(in alert: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for text in alert.staticTexts.allElementsBoundByIndex.map(\.label) {
            XCTAssertFalse(text.contains("{") || text.contains("statusCode"), "Alert shows raw JSON: \(text)", file: file, line: line)
        }
    }
}
