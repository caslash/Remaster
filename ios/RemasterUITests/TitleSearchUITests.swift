//
//  TitleSearchUITests.swift
//  RemasterUITests
//
//  Searching for a title by name (RMSTR-16): opened from Library's + menu or
//  the empty library's Search by Title (no barcode), and from the confirm
//  sheet's "Not this title? Search instead" (with the scanned UPC).
//
//  The app launches with SIMULATED_SERVICES, so SimulatedTitleService answers
//  from ios/Mocks/Titles.bundle ("hoppers", "grinch", "wandavision"; any other
//  query has no matches) and fakes errors for "000" (offline), "503" (busy,
//  retry after 5 s), "504" and "unexpected". Each result is one button
//  (page.titleSearch.result) whose label reads "<name>, <Movie|TV> · <year>",
//  without the year when TMDB has none.
//
//  Debounce timing is covered by TitleSearchViewModelTests; picking a result
//  from the no-barcode search continues to "Pick the format I own" (RMSTR-17),
//  which isn't built yet.
//

import XCTest

@MainActor
final class TitleSearchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES"]
        app.launch()
    }

    // MARK: Entry points without a barcode

    func testAddMenuOpensSearchWithNoBarcodeCard() {
        openSearchFromAddMenu()

        XCTAssertTrue(app.navigationBars["Add Title"].exists || app.staticTexts["Add Title"].exists, "The search isn't titled Add Title")
        XCTAssertFalse(app.staticTexts["We don't know this barcode yet"].exists, "A search without a barcode shows the unmatched-barcode card")
        XCTAssertEqual(searchField.value as? String ?? "", searchField.placeholderValue ?? "", "The search field should start empty")
        XCTAssertTrue(idle.exists, "The search doesn't start on its Find a title prompt")
        XCTAssertFalse(app.textFields["page.scanning.manualEntry.field"].exists, "Search by Title opened the scanner")
        XCTAssertFalse(app.buttons["page.scanning.dismiss"].exists, "The search sheet's Close carries the scanner's identifier")
    }

    func testEmptyLibrarySearchByTitleOpensSearch() {
        let searchByTitle = app.buttons.matching(NSPredicate(format: "label == 'Search by Title' AND identifier == ''")).firstMatch
        XCTAssertTrue(searchByTitle.waitForExistence(timeout: 10), "The empty library has no Search by Title button")

        searchByTitle.tap()

        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search by Title didn't open the search")
    }

    func testCloseReturnsToLibrary() {
        openSearchFromAddMenu()

        XCTAssertTrue(closeSearch.waitForExistence(timeout: 5), "The search sheet has no Close")
        XCTAssertFalse(closeSearch.label.isEmpty, "Close has no VoiceOver label")
        closeSearch.tap()

        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Close didn't dismiss the search")
        XCTAssertTrue(addNew.waitForExistence(timeout: 5), "Closing the search didn't return to Library")
    }

    // MARK: AC 1: 2+ characters show matching movies and shows

    func testOneCharacterDoesNotSearch() {
        openSearchFromAddMenu()

        search("h")

        // Longer than the 300 ms debounce plus the simulated 200 ms request.
        sleep(1)
        XCTAssertEqual(results.count, 0, "A single character ran a search")
        XCTAssertFalse(app.descendants(matching: .any)["page.titleSearch.noMatches"].exists, "A single character showed No matches")
    }

    func testTypingShowsMatchingTitlesWithTypeAndYear() {
        openSearchFromAddMenu()

        search("hoppers")

        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 5), "No results for hoppers")
        let labels = results.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains("Hoppers, Movie · 2026"), "Results: \(labels)")
        XCTAssertTrue(labels.contains("De Hoppers, TV · 2019"), "Results: \(labels)")
    }

    func testResultsWithoutAPosterReadTheNameOnce() {
        openSearchFromAddMenu()

        search("hoppers")

        // Space Hoppers and Hip Hoppers have no poster, so their fallback poster
        // draws the name; VoiceOver should still read it only once.
        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 5), "No results for hoppers")
        let labels = results.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains("Space Hoppers, TV"), "Results: \(labels)")
        XCTAssertTrue(labels.contains("Hip Hoppers, Movie"), "Results: \(labels)")
    }

    // MARK: AC 2: the year tells same-named works apart

    func testSameNamedTitlesShowTheirYears() {
        openSearchFromAddMenu()

        search("grinch")

        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 5), "No results for grinch")
        let labels = results.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.hasPrefix("How the Grinch Stole Christmas,") && $0.hasSuffix("2000") }, "Results: \(labels)")
        XCTAssertTrue(labels.contains { $0.hasPrefix("How the Grinch Stole Christmas!,") && $0.hasSuffix("1966") }, "Results: \(labels)")
    }

    // MARK: AC 3: no results show No matches with tips

    func testNoResultsShowNoMatchesWithTips() {
        openSearchFromAddMenu()

        search("zzzz")

        let noMatches = app.descendants(matching: .any)["page.titleSearch.noMatches"].firstMatch
        XCTAssertTrue(noMatches.waitForExistence(timeout: 5), "No No-matches message for zzzz")
        XCTAssertEqual(results.count, 0, "Results shown for zzzz")
        let tip = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'original title' OR label CONTAINS[c] 'year'")).firstMatch
        XCTAssertTrue(tip.exists, "No matches doesn't suggest the original title or the year. Texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
    }

    // MARK: AC 4: offline shows a message, not an endless spinner

    func testOfflineShowsAMessageInsteadOfASpinner() {
        openSearchFromAddMenu()

        search("000")

        let errorTitle = app.staticTexts["page.titleSearch.error.title"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: 5), "No offline message")
        XCTAssertEqual(errorTitle.label, "You're offline")
        XCTAssertEqual(app.staticTexts["page.titleSearch.error.message"].label, "Connect to Wi-Fi or mobile data to search.")
        XCTAssertFalse(app.descendants(matching: .any)["page.titleSearch.progress"].exists, "The spinner is still showing after going offline")
    }

    func testBusyServerOffersToRetry() {
        openSearchFromAddMenu()

        search("503")

        XCTAssertTrue(app.descendants(matching: .any)["page.titleSearch.busy"].firstMatch.waitForExistence(timeout: 5), "No busy message when the server asks to retry later")
        XCTAssertTrue(app.buttons["page.titleSearch.retryNow"].exists, "No way to retry now")
    }

    func testCorrectingTheQueryAfterNoMatchesFindsTitles() {
        openSearchFromAddMenu()
        search("zzzz")
        XCTAssertTrue(app.descendants(matching: .any)["page.titleSearch.noMatches"].firstMatch.waitForExistence(timeout: 5), "No No-matches message for zzzz")

        app.buttons["page.titleSearch.clear"].tap()
        search("wandavision")

        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 5), "Correcting the query didn't search again")
        XCTAssertTrue(results.allElementsBoundByIndex.map(\.label).contains("WandaVision, TV · 2021"))
    }

    // MARK: From the confirm sheet (AC moved from RMSTR-14)

    func testNotThisTitleOpensSearchPrefilledWithTheDetectedTitle() {
        openNotThisTitle("043396648654")

        XCTAssertTrue(app.staticTexts["We found this disc, not its title"].exists, "No card for the scanned disc")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'UPC 043396648654'")).firstMatch.exists, "The card doesn't show the scanned UPC")
        XCTAssertEqual(searchField.value as? String, "Hoppers", "The search isn't pre-filled with the detected title")
        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 5), "The pre-filled search didn't run")
    }

    func testNotThisTitleHasBackButNoClose() {
        openNotThisTitle("043396648654")

        XCTAssertTrue(app.buttons["BackButton"].exists || app.navigationBars.buttons.firstMatch.exists, "No Back from the search to the confirm sheet")
        // Manual entry's Close is still in the tree under the confirm sheet, but
        // not hittable; only a Close on the search screen itself would be.
        let hittableClose = app.buttons.matching(NSPredicate(format: "label == 'Close'")).allElementsBoundByIndex.filter(\.isHittable)
        XCTAssertTrue(hittableClose.isEmpty, "The pushed search shows its own Close as well as Back: \(hittableClose.map(\.identifier))")
    }

    func testPickingATitleReturnsToTheConfirmSheet() {
        openNotThisTitle("043396648654")
        let pick = results.matching(NSPredicate(format: "label BEGINSWITH 'De Hoppers,'")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "No De Hoppers result")

        // Taps the middle of the row, past the end of the short name, so the
        // whole row has to be tappable, not just its text and poster.
        pick.tap()

        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5), "Picking a title didn't leave the search")
        XCTAssertTrue(app.buttons["page.confirm.add"].waitForExistence(timeout: 5), "Picking a title didn't return to the confirm sheet")
    }

    // MARK: Helpers

    private var searchField: XCUIElement {
        app.textFields["page.titleSearch.field"]
    }

    private var idle: XCUIElement {
        app.descendants(matching: .any)["page.titleSearch.idle"].firstMatch
    }

    private var results: XCUIElementQuery {
        app.buttons.matching(identifier: "page.titleSearch.result")
    }

    /// Library's + toolbar menu, matched by "Add new" or the bare + image's "Add".
    private var addNew: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN {'Add new', 'Add'}")).firstMatch
    }

    /// The search sheet's Close, which Library adds when it presents the search.
    /// Found by identifier, not through a navigation bar: on iPhone Duo the
    /// toolbar is a vertical rail outside the NavigationBar element.
    private var closeSearch: XCUIElement {
        app.buttons["page.titleSearch.dismiss"].firstMatch
    }

    private func openSearchFromAddMenu(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "Library's + button didn't appear", file: file, line: line)
        addNew.tap()
        let item = app.collectionViews.buttons["Search by Title"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "The + menu has no Search by Title", file: file, line: line)
        item.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search by Title didn't open the search", file: file, line: line)
    }

    private func search(_ text: String) {
        searchField.tap()
        searchField.typeText(text)
    }

    /// Looks up the barcode through the scanner's manual entry, then taps the
    /// confirm sheet's "Not this title? Search instead".
    private func openNotThisTitle(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "Library's + button didn't appear", file: file, line: line)
        addNew.tap()
        let scan = app.collectionViews.buttons["Scan a Shelf"].firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: 5), "The + menu has no Scan a Shelf", file: file, line: line)
        scan.tap()

        let field = app.textFields["page.scanning.manualEntry.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Manual entry field didn't appear", file: file, line: line)
        field.tap()
        field.typeText(barcode)
        app.buttons["page.scanning.manualEntry.search"].tap()

        let notThis = app.buttons["page.confirm.notThis"]
        XCTAssertTrue(notThis.waitForExistence(timeout: 5), "Confirm sheet didn't appear", file: file, line: line)
        notThis.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Not this title didn't open the search", file: file, line: line)
    }
}
