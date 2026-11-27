//
//  AddToLibraryUITests.swift
//  RemasterUITests
//
//  Saving from the confirm sheet (RMSTR-14): the "Added to Library" banner, the
//  owned formats it names, and the duplicate check before a second copy.
//
//  The app launches with SIMULATED_SERVICES, which also swaps in an in-memory
//  library store, so every test starts with an empty library. Each test opens
//  the scanner from Library's Add new (+) button and types a barcode from ios/Mocks/Editions.bundle into the manual entry
//  field, as EditionLookupUITests does.
//
//  The banner is one combined accessibility element (banner.added) whose label
//  reads "Added to Library" followed by "<upcTitle> · <formats>".
//

import XCTest

@MainActor
final class AddToLibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["SIMULATED_SERVICES"]
        app.launch()
    }

    // MARK: Confirmation within 1 s

    func testAddingShowsTheBannerWithinASecond() {
        openConfirm("786936900378")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(banner.label.contains("Added to Library"), "Banner label: \(banner.label)")
        XCTAssertTrue(banner.label.contains("WandaVision: The Complete Series · 4K UHD"), "Banner label: \(banner.label)")
    }

    func testAddingClosesTheScanner() {
        openConfirm("786936900378")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForNonExistence(timeout: 5), "Confirm sheet stayed up after Add")
        XCTAssertTrue(manualEntryField.waitForNonExistence(timeout: 5), "Scanner stayed up after Add")
        XCTAssertTrue(banner.exists, "Banner went away with the scanner")
    }

    // MARK: Owned formats

    // Hoppers is 4K + Blu-ray and the combo toggle starts on, so both are owned.
    func testComboPackBannerNamesBothFormats() {
        openConfirm("043396648654")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(banner.label.contains("Hoppers · 4K UHD + Blu-ray"), "Banner label: \(banner.label)")
    }

    func testComboToggleOffSavesOnlyThePickedFormat() {
        openConfirm("043396648654")
        XCTAssertTrue(comboToggle.exists, "Combo toggle missing for a 4K + Blu-ray set")

        turnComboToggleOff()
        XCTAssertEqual(comboToggle.value as? String, "0", "Combo toggle didn't turn off")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(banner.label.contains("Hoppers · 4K UHD"), "Banner label: \(banner.label)")
        XCTAssertFalse(banner.label.contains("Blu-ray"), "Blu-ray saved with the combo toggle off: \(banner.label)")
    }

    // MARK: Dismissing the banner

    // The banner doesn't hide on its own, so VoiceOver has time to read it.
    func testBannerStaysUntilTapped() {
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")

        XCTAssertFalse(banner.waitForNonExistence(timeout: 6), "Banner hid itself before it was tapped")

        banner.tap()

        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Tapping the banner didn't dismiss it")
    }

    // MARK: Taps outside the banner

    // The banner sits in its own window over the whole screen; a tap outside it
    // must still reach the app underneath.
    func testTapOutsideTheBannerReachesTheTabs() {
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(manualEntryField.waitForNonExistence(timeout: 5), "Scanner stayed up after Add")

        upgradesTab.tap()

        XCTAssertTrue(waitUntilSelected(upgradesTab), "Tapping Upgrades with the banner showing didn't select it")
    }

    func testTapOutsideTheBannerDismissesIt() {
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(manualEntryField.waitForNonExistence(timeout: 5), "Scanner stayed up after Add")

        upgradesTab.tap()

        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Tapping outside the banner didn't dismiss it")
    }

    func testScannerOpensAgainWithTheBannerShowing() {
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add")
        XCTAssertTrue(manualEntryField.waitForNonExistence(timeout: 5), "Scanner stayed up after Add")

        app.buttons["Add new"].firstMatch.tap()

        XCTAssertTrue(manualEntryField.waitForExistence(timeout: 5), "Tapping Add new with the banner showing didn't open the scanner")
    }

    // MARK: Duplicates

    func testSameDiscAgainAsksBeforeAdding() {
        addThenDismissBanner("786936900378")
        openConfirm("786936900378")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(addAnotherCopy.waitForExistence(timeout: 5), "No duplicate warning for the same disc")
        XCTAssertTrue(app.staticTexts["Already in your library"].exists, "Duplicate warning doesn't say Already in your library")
        XCTAssertTrue(app.staticTexts["Own a second copy? Add it so your library count stays right."].exists, "Duplicate warning is missing its message")
        XCTAssertFalse(banner.exists, "Banner shown for a copy that wasn't saved")
    }

    func testCancellingTheDuplicateWarningKeepsTheSheet() {
        addThenDismissBanner("786936900378")
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(addAnotherCopy.waitForExistence(timeout: 5), "No duplicate warning for the same disc")

        // On iPhone the dialog is a popover with no Cancel button; tapping outside
        // it is the cancel.
        tapOutsidePopover()

        XCTAssertTrue(addAnotherCopy.waitForNonExistence(timeout: 5), "Duplicate warning stayed up after Cancel")
        XCTAssertTrue(app.staticTexts["page.confirm.title"].exists, "Confirm sheet closed after Cancel")
        XCTAssertFalse(banner.exists, "Banner shown after cancelling")
        XCTAssertTrue(app.buttons["page.confirm.add"].isEnabled, "Add to Library stayed disabled after Cancel")
    }

    func testAddAnotherCopySavesAndShowsTheBanner() {
        addThenDismissBanner("786936900378")
        openConfirm("786936900378")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(addAnotherCopy.waitForExistence(timeout: 5), "No duplicate warning for the same disc")

        addAnotherCopy.tap()

        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No Added to Library banner within 1 s of Add Another Copy")
        XCTAssertTrue(banner.label.contains("WandaVision: The Complete Series · 4K UHD"), "Banner label: \(banner.label)")
        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForNonExistence(timeout: 5), "Confirm sheet stayed up after Add Another Copy")
    }

    // MARK: Adding a format to the copy you own

    // Hoppers saved as 4K only, then rescanned with the combo toggle on: the
    // dialog offers to add Blu-ray to the saved copy instead of a second copy.
    func testRescanWithANewFormatOffersToUpdateTheCopy() {
        saveHoppersAs4KOnly()
        openConfirm("043396648654")
        XCTAssertEqual(comboToggle.value as? String, "1", "Combo toggle didn't start on")

        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(app.staticTexts["Already in your library"].waitForExistence(timeout: 5), "No duplicate warning for the same disc")
        XCTAssertTrue(app.staticTexts["Add Blu-ray to your copy?"].exists, "Warning doesn't name the missing format")
        XCTAssertTrue(addToYourCopy.exists, "No button to add the format to your copy")
        XCTAssertFalse(addToYourCopy.label.isEmpty, "The add-to-your-copy button has no label")
        XCTAssertTrue(addAnotherCopy.exists || app.buttons["Add as Another Copy"].exists, "Adding another copy is no longer offered")
    }

    func testAddingTheFormatUpdatesTheCopy() {
        saveHoppersAs4KOnly()
        openConfirm("043396648654")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(addToYourCopy.waitForExistence(timeout: 5), "No button to add the format to your copy")

        addToYourCopy.tap()

        XCTAssertTrue(banner.waitForExistence(timeout: 1), "No banner within 1 s of updating the copy")
        XCTAssertTrue(banner.label.contains("Updated your copy"), "Banner label: \(banner.label)")
        XCTAssertFalse(banner.label.contains("Added to Library"), "Banner says Added for an update: \(banner.label)")
        XCTAssertTrue(banner.label.contains("Hoppers · 4K UHD + Blu-ray"), "Banner label: \(banner.label)")
        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForNonExistence(timeout: 5), "Confirm sheet stayed up after updating the copy")
    }

    // After the update, the same rescan is a plain duplicate: the copy now has both formats.
    func testUpdatedCopyIsThenAPlainDuplicate() {
        saveHoppersAs4KOnly()
        openConfirm("043396648654")
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(addToYourCopy.waitForExistence(timeout: 5), "No button to add the format to your copy")
        addToYourCopy.tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Copy wasn't updated")
        banner.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Banner didn't dismiss")

        openConfirm("043396648654")
        app.buttons["page.confirm.add"].tap()

        XCTAssertTrue(app.staticTexts["Own a second copy? Add it so your library count stays right."].waitForExistence(timeout: 5), "Rescan after the update isn't a plain duplicate")
        XCTAssertFalse(addToYourCopy.exists, "Still offering to add a format the copy now has")
    }

    // MARK: Helpers

    /// Matched by identifier or label, as in AppShellUITests: iOS 27.0 doesn't
    /// expose `tab.*` identifiers, and iPhone Duo's tab rail isn't a TabBar.
    private var upgradesTab: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'tab.upgrades' OR label == 'Upgrades'")).firstMatch
    }

    /// Selection can lag a tap by a frame or two, so wait for it.
    private func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter.wait(for: [selected], timeout: timeout) == .completed
    }

    private var addToYourCopy: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'your copy'")).firstMatch
    }

    /// Saves Hoppers (4K + Blu-ray) with the combo toggle off, so the copy only has 4K UHD.
    private func saveHoppersAs4KOnly(file: StaticString = #filePath, line: UInt = #line) {
        openConfirm("043396648654", file: file, line: line)
        turnComboToggleOff()
        XCTAssertEqual(comboToggle.value as? String, "0", "Combo toggle didn't turn off", file: file, line: line)
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Hoppers wasn't saved", file: file, line: line)
        XCTAssertTrue(banner.label.contains("Hoppers · 4K UHD"), "Banner label: \(banner.label)", file: file, line: line)
        banner.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Banner didn't dismiss", file: file, line: line)
    }

    /// Taps the switch inside the combo row, not the row: the row's frame spans the
    /// label too, and how far its trailing edge sits past the switch depends on the
    /// screen (on iPhone Duo a tap at 95% of the row lands on the switch's edge).
    private func turnComboToggleOff() {
        let control = comboToggle.switches.firstMatch
        if control.exists {
            control.tap()
        } else {
            comboToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
    }

    /// Dismisses the duplicate warning popover by tapping outside it. Not through
    /// `PopoverDismissRegion`: the sheet and the popover each add one, and on iPhone
    /// Duo `firstMatch` isn't the popover's, so the tap does nothing.
    private func tapOutsidePopover() {
        let window = app.windows.firstMatch.frame
        let popover = app.popovers.firstMatch.frame
        let x = window.midX
        // Tap halfway into whichever gap, above or below the popover, is larger.
        let y = (popover.minY - window.minY) > (window.maxY - popover.maxY)
            ? (window.minY + popover.minY) / 2
            : (popover.maxY + window.maxY) / 2
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - window.minX, dy: y - window.minY))
            .tap()
    }

    private var banner: XCUIElement {
        app.descendants(matching: .any)["banner.added"].firstMatch
    }

    private var addAnotherCopy: XCUIElement {
        app.buttons["Add Another Copy"].firstMatch
    }

    private var manualEntryField: XCUIElement {
        app.textFields["page.scanning.manualEntry.field"]
    }

    private var comboToggle: XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Also includes'")).firstMatch
    }

    /// Opens the scanner from Library's Add new button, looks up the barcode and waits for the confirm sheet.
    private func openConfirm(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        let addNew = app.buttons["Add new"].firstMatch
        XCTAssertTrue(addNew.waitForExistence(timeout: 10), "Library's Add new button didn't appear", file: file, line: line)
        addNew.tap()

        XCTAssertTrue(manualEntryField.waitForExistence(timeout: 5), "Manual entry field didn't appear", file: file, line: line)
        manualEntryField.tap()
        manualEntryField.typeText(barcode)
        app.buttons["page.scanning.manualEntry.search"].tap()

        XCTAssertTrue(app.staticTexts["page.confirm.title"].waitForExistence(timeout: 5), "Confirm sheet didn't appear", file: file, line: line)
    }

    /// Saves the disc once and clears the banner, so the next save starts clean.
    private func addThenDismissBanner(_ barcode: String, file: StaticString = #filePath, line: UInt = #line) {
        openConfirm(barcode, file: file, line: line)
        app.buttons["page.confirm.add"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "First copy wasn't saved", file: file, line: line)
        banner.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "Banner didn't dismiss", file: file, line: line)
    }
}
