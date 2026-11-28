//
//  XCUIElement+Typing.swift
//  RemasterUITests
//
//  Typing straight after tapping a text field is flaky on a busy simulator:
//  the field may not have keyboard focus yet, and typeText fails with
//  "Neither element nor any descendant has keyboard focus". Wait for focus,
//  tapping again if it doesn't come, before typing.
//

import XCTest

extension XCUIElement {

    /// Taps the field, waits until it has keyboard focus, then types the text.
    func tapAndType(_ text: String, attempts: Int = 3, file: StaticString = #filePath, line: UInt = #line) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")

        for _ in 0..<attempts {
            tap()
            let expectation = XCTNSPredicateExpectation(predicate: focused, object: self)
            if XCTWaiter().wait(for: [expectation], timeout: 3) == .completed {
                typeText(text)
                return
            }
        }

        XCTFail("\(identifier) never got keyboard focus after \(attempts) taps", file: file, line: line)
    }
}
