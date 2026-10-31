//
//  EditionLookupUITests.swift
//  RemasterUITests
//
//  What the user sees after a lookup (RMSTR-11 AC 3, 4 and 5).
//
//  The app launches with SIMULATED_SERVICES, so SimulatedBarcodeService answers
//  from ios/Mocks/Editions.bundle and fakes errors for 000 (offline), 400, 404
//  and 503. The camera scanner isn't supported in the Simulator, so barcodes are
//  typed into the manual entry alert.
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

        let title = app.staticTexts["sheet.edition.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Edition sheet didn't appear")
        XCTAssertEqual(title.label, "WandaVision: The Complete Series")
        XCTAssertEqual(app.staticTexts["sheet.edition.format"].label, "4K UHD")
    }

    // MARK: AC 4: not found shows a not-found message

    func testNotFoundShowsMessageWithoutRetry() {
        lookUp("404")

        let alert = app.alerts["We don't know this disc yet"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Not-found alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertFalse(alert.buttons["Retry"].exists, "Retrying an unknown disc can't succeed")

        alert.buttons["OK"].tap()

        XCTAssertTrue(manualEntry.waitForExistence(timeout: 5), "Manual entry didn't come back after dismissing")
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

        alert.buttons["Retry"].tap()

        // The alert goes away while the lookup runs, then the same failure brings it back.
        // The gap is only a few hundred milliseconds, shorter than waitForNonExistence's
        // polling interval, so check in a tight loop instead.
        XCTAssertTrue(disappears(alert, within: 5), "Alert stayed up after Retry")
        XCTAssertFalse(manualEntry.exists, "Retry fell back to manual entry instead of looking up again")
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Retry didn't run the lookup again")
    }

    // MARK: Bad scan (upc-endpoint.md: 400 means scan again, don't retry)

    func testBadScanShowsMessageWithoutRetry() {
        lookUp("400")

        let alert = app.alerts["That's not a disc barcode"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Bad scan alert didn't appear")
        assertNoRawJSON(in: alert)
        XCTAssertFalse(alert.buttons["Retry"].exists, "Retrying the same bad code can't succeed")

        alert.buttons["OK"].tap()

        XCTAssertTrue(manualEntry.waitForExistence(timeout: 5), "Manual entry didn't come back after dismissing")
    }

    // MARK: Helpers

    private var manualEntry: XCUIElement {
        app.alerts["Search a UPC"]
    }

    private func lookUp(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(manualEntry.waitForExistence(timeout: 10), "Manual entry alert didn't appear", file: file, line: line)

        let field = manualEntry.textFields.firstMatch
        field.tap()
        field.typeText(barcode)
        manualEntry.buttons["OK"].tap()
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
