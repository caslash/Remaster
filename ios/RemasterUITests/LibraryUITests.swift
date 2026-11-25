//
//  LibraryUITests.swift
//  RemasterUITests
//
//  The Library tab (RMSTR-18): a card for each saved disc (AC 1), the detail
//  screen a card opens (AC 5), and deleting from the detail screen or the
//  card's context menu (AC 6).
//
//  The app launches with SIMULATED_SERVICES, so the library starts empty in an
//  in-memory store and lookups come from ios/Mocks/Editions.bundle. Discs are
//  saved through Scan, as AddToLibraryUITests does:
//  - WandaVision (786936900378): matched, 4K UHD, steelbook + collector's.
//  - Hoppers (043396648654): matched, 4K UHD + Blu-ray, steelbook.
//  - The Grinch (0191329282809): unmatched (no TMDB title or kind), anniversary.
//
//  On the detail screen each LabeledContent row is one accessibility element
//  whose label reads "<row>, <value>" (what VoiceOver says), so rows are found
//  by their identifier and checked against that whole label.
//
//  Whether a deleted copy stays deleted after relaunch can't be checked here
//  (the simulated store is in memory); LibraryServiceTests covers the save.
//

import XCTest

@MainActor
final class LibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES"]
        app.launch()
    }

    // MARK: AC 1: a card with the title and a format badge

    func testSavedDiscShowsAsACardWithTitleAndFormat() {
        save("786936900378")

        openLibrary()

        let card = card(titled: "WandaVision")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No card for the saved disc. Cards: \(cardLabels)")
        XCTAssertTrue(card.label.contains("4K"), "The card doesn't show the 4K format badge: \(card.label)")
    }

    func testAComboPackCardShowsBothFormats() {
        save("043396648654")

        openLibrary()

        let card = card(titled: "Hoppers")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No card for Hoppers. Cards: \(cardLabels)")
        XCTAssertTrue(card.label.contains("4K"), "Card label: \(card.label)")
        XCTAssertTrue(card.label.contains("BD"), "The card doesn't show the Blu-ray badge: \(card.label)")
    }

    // MARK: AC 5: tapping a card shows the entry's details

    func testTappingACardOpensItsDetails() {
        save("786936900378")
        openLibrary()

        openDetail(titled: "WandaVision")

        XCTAssertEqual(detailTitle.label, "WandaVision")
        XCTAssertEqual(detailRow("formats").label, "Formats, 4K UHD")
        XCTAssertEqual(detailRow("edition").label, "Edition, Steelbook")
        XCTAssertEqual(detailRow("upc").label, "UPC, 786936900378")
        XCTAssertTrue(detailDelete.exists, "No Delete on the detail screen")
    }

    func testOneCopyDoesNotShowACopiesCount() {
        save("786936900378")
        openLibrary()

        openDetail(titled: "WandaVision")

        XCTAssertFalse(detailRow("copies").exists, "A single copy shows a Copies row: \(detailRow("copies").label)")
    }

    func testTwoCopiesShowACopiesCountOfTwo() {
        save("786936900378")
        saveAnotherCopy("786936900378")
        openLibrary()

        openDetail(titled: "WandaVision")

        XCTAssertTrue(detailRow("copies").waitForExistence(timeout: 5), "No Copies row with two copies saved")
        XCTAssertEqual(detailRow("copies").label, "Copies, 2")
    }

    // The Grinch has no TMDB match, so its copy has no kind: opening it used to
    // force-unwrap a nil kind and crash.
    func testAnUnmatchedDiscOpensItsDetails() {
        save("0191329282809")
        openLibrary()

        openDetail(titled: "Grinch")

        XCTAssertEqual(detailTitle.label, "Dr. Seuss' How the Grinch Stole Christmas")
        XCTAssertEqual(detailRow("edition").label, "Edition, Anniversary")
    }

    // MARK: AC 6: deleting removes the entry from the grid

    func testDeleteAsksFirst() {
        save("786936900378")
        openLibrary()
        openDetail(titled: "WandaVision")

        detailDelete.tap()

        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete didn't ask for confirmation")
    }

    func testCancellingDeleteKeepsTheCopy() {
        save("786936900378")
        openLibrary()
        openDetail(titled: "WandaVision")
        detailDelete.tap()
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete didn't ask for confirmation")

        cancelDelete()

        XCTAssertTrue(confirmDelete.waitForNonExistence(timeout: 5), "The confirmation stayed up after Cancel")
        XCTAssertTrue(detailTitle.exists, "Cancelling left the detail screen")
        goBack()
        XCTAssertTrue(card(titled: "WandaVision").waitForExistence(timeout: 5), "The card went away after cancelling Delete")
    }

    func testDeletingFromTheDetailScreenRemovesTheCard() {
        save("786936900378")
        openLibrary()
        openDetail(titled: "WandaVision")

        detailDelete.tap()
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete didn't ask for confirmation")
        confirmDelete.tap()

        XCTAssertTrue(detailTitle.waitForNonExistence(timeout: 5), "The detail screen stayed up after Delete")
        XCTAssertTrue(card(titled: "WandaVision").waitForNonExistence(timeout: 5), "The deleted copy's card is still in the grid")
    }

    func testDeletingOneCopyLeavesTheOthers() {
        save("786936900378")
        save("043396648654")
        openLibrary()
        openDetail(titled: "Hoppers")

        detailDelete.tap()
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete didn't ask for confirmation")
        confirmDelete.tap()

        XCTAssertTrue(card(titled: "Hoppers").waitForNonExistence(timeout: 5), "Hoppers is still in the grid")
        XCTAssertTrue(card(titled: "WandaVision").exists, "Deleting Hoppers also removed WandaVision")
    }

    func testDeletingFromTheCardMenuRemovesTheCard() {
        save("786936900378")
        openLibrary()
        let card = card(titled: "WandaVision")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No card for the saved disc. Cards: \(cardLabels)")

        card.press(forDuration: 1.2)
        let menuDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(menuDelete.waitForExistence(timeout: 5), "The card's context menu has no Delete")
        menuDelete.tap()

        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "The card is still in the grid after deleting from its menu")
    }

    // MARK: Helpers

    private var cards: XCUIElementQuery {
        app.buttons.matching(identifier: "page.library.card")
    }

    private var cardLabels: [String] {
        cards.allElementsBoundByIndex.map(\.label)
    }

    private func card(titled title: String) -> XCUIElement {
        cards.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private var detailTitle: XCUIElement {
        app.staticTexts["page.libraryDetail.title"]
    }

    private func detailRow(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)["page.libraryDetail.\(name)"].firstMatch
    }

    private var detailDelete: XCUIElement {
        app.buttons["page.libraryDetail.delete"]
    }

    /// The confirmation dialog's Delete. A dialog button with an identifier
    /// shows up twice in the accessibility tree, hence firstMatch.
    private var confirmDelete: XCUIElement {
        app.buttons["page.libraryDetail.delete.confirm"].firstMatch
    }

    /// On iPhone the confirmation is an action sheet with a Cancel button; as a
    /// popover (wider layouts) tapping outside it is the cancel.
    private func cancelDelete() {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists && cancel.isHittable {
            cancel.tap()
        } else {
            app.otherElements["PopoverDismissRegion"].firstMatch.tap()
        }
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func openLibrary(file: StaticString = #filePath, line: UInt = #line) {
        let library = app.buttons.matching(NSPredicate(format: "identifier == 'tab.library' OR label == 'Library'")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10), "Library tab is missing", file: file, line: line)
        library.tap()
    }

    private func openDetail(titled title: String, file: StaticString = #filePath, line: UInt = #line) {
        let card = card(titled: title)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No card for \(title). Cards: \(cardLabels)", file: file, line: line)
        card.tap()
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 5), "Tapping the \(title) card didn't open its details", file: file, line: line)
    }

    private var banner: XCUIElement {
        app.descendants(matching: .any)["banner.added"].firstMatch
    }

    private var manualEntryField: XCUIElement {
        app.textFields["page.scanning.manualEntry.field"]
    }

    /// Opens Scan, looks up the barcode and waits for the confirm sheet.
    private func openConfirm(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        let scan = app.buttons["Scan"].firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: 10), "Scan action didn't appear", file: file, line: line)
        scan.tap()

        XCTAssertTrue(manualEntryField.waitForExistence(timeout: 5), "Manual entry field didn't appear", file: file, line: line)
        manualEntryField.tap()
        manualEntryField.typeText(barcode)
        app.buttons["page.scanning.manualEntry.search"].tap()

        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForExistence(timeout: 5), "Confirm sheet didn't appear", file: file, line: line)
    }

    private func dismissBanner(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "The disc wasn't saved", file: file, line: line)
        banner.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Banner didn't dismiss", file: file, line: line)
    }

    /// Saves the disc through Scan with its default formats and clears the banner.
    private func save(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        openConfirm(barcode, file: file, line: line)
        app.buttons["page.confirm.add"].tap()
        dismissBanner(file: file, line: line)
    }

    /// Saves a second copy of a disc that's already in the library.
    private func saveAnotherCopy(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        openConfirm(barcode, file: file, line: line)
        app.buttons["page.confirm.add"].tap()
        let addAnotherCopy = app.buttons["Add Another Copy"].firstMatch
        XCTAssertTrue(addAnotherCopy.waitForExistence(timeout: 5), "No duplicate warning for the second copy", file: file, line: line)
        addAnotherCopy.tap()
        dismissBanner(file: file, line: line)
    }
}
