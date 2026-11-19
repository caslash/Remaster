//
//  EditionLookupUITests.swift
//  RemasterUITests
//
//  What the user sees after a lookup (RMSTR-11 AC 3, 4 and 5).
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

    func testFoundEditionShowsTitleAndFormat() {
        lookUp("786936900378")

        let title = app.staticTexts["page.scanning.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Edition sheet didn't appear")
        XCTAssertEqual(title.label, "WandaVision: The Complete Series")
        XCTAssertEqual(app.staticTexts["page.scanning.format"].label, "4K UHD")
    }

    // MARK: AC 4: not found shows a not-found message

    func testNotFoundShowsMessageWithoutRetry() {
        lookUp("404")

        let alert = app.alerts["We don't know this disc yet"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Not-found alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertFalse(alert.buttons["Retry"].exists, "Retrying an unknown disc can't succeed")

        alert.buttons["OK"].firstMatch.tap()

        assertManualEntryIsReady()
    }

    // MARK: AC 5: a network or backend failure is retryable

    func testBackendFailureOffersRetry() {
        lookUp("503")

        let alert = app.alerts["Remaster is having trouble"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Backend error alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        XCTAssertTrue(alert.buttons["OK"].exists)
    }

    func testOfflineOffersRetry() {
        lookUp("000")

        let alert = app.alerts["You're offline"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Offline alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertTrue(alert.buttons["Retry"].exists)
    }

    func testRetryRunsTheLookupAgain() {
        lookUp("503")
        let alert = app.alerts["Remaster is having trouble"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))

        alert.buttons["Retry"].firstMatch.tap()

        // The alert goes away while the lookup runs, then the same failure brings it back.
        // The gap is only a few hundred milliseconds, shorter than waitForNonExistence's
        // polling interval, so check in a tight loop instead.
        XCTAssertTrue(disappears(alert, within: 5), "Alert stayed up after Retry")
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Retry didn't run the lookup again")
    }

    // MARK: Bad scan (upc-endpoint.md: 400 means scan again, don't retry)

    func testBadScanShowsMessageWithoutRetry() {
        lookUp("400")

        let alert = app.alerts["That's not a disc barcode"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Bad scan alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertFalse(alert.buttons["Retry"].exists, "Retrying the same bad code can't succeed")

        alert.buttons["OK"].firstMatch.tap()

        assertManualEntryIsReady()
    }

    // MARK: Manual entry is paused while a lookup runs

    func testManualEntryIsDisabledWhileLookingUp() {
        lookUp("503")

        // The simulated service waits at least MINIMUM_WAIT before answering, so the
        // field is still disabled right after Search.
        XCTAssertFalse(manualEntryField.isEnabled, "Manual entry stayed enabled during the lookup")
        XCTAssertTrue(app.alerts["Remaster is having trouble"].waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    private var manualEntryField: XCUIElement {
        app.textFields["page.scanning.manualEntry.field"]
    }

    private var manualEntrySearch: XCUIElement {
        app.buttons["page.scanning.manualEntry.search"]
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
