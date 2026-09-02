import XCTest
@testable import LocalizationInspector

final class KeyMatcherTests: XCTestCase {

    private let entries = [
        "welcome.title": "Welcome to Zorlu World",
        "welcome.subtitle": "Manage your home from anywhere",
        "login.button": "Log In",
        "settings.turkish": "Türkçe",
        "duplicate.a": "Save",
        "duplicate.b": "Save"
    ]

    private func matcher(partial: Bool = true, undefined: Bool = true) -> KeyMatcher {
        KeyMatcher(entries: entries, allowsPartialMatch: partial, detectsUndefinedKeys: undefined)
    }

    func testExactMatchReturnsSingleKey() {
        XCTAssertEqual(matcher().classify("Welcome to Zorlu World"),
                       .backendDefined(keys: ["welcome.title"]))
    }

    func testExactMatchReturnsAllDuplicateKeysSorted() {
        XCTAssertEqual(matcher().classify("Save"),
                       .backendDefined(keys: ["duplicate.a", "duplicate.b"]))
    }

    func testPartialMatchWhenEnabled() {
        XCTAssertEqual(matcher(partial: true).classify("Please Log In now"),
                       .backendDefined(keys: ["login.button"]))
    }

    func testPartialMatchIgnoredWhenDisabled() {
        XCTAssertEqual(matcher(partial: false).classify("Please Log In now"), .staticText)
    }

    func testUndefinedKeyPathDetected() {
        XCTAssertEqual(matcher().classify("account.deletion.title"),
                       .backendUndefined(key: "account.deletion.title"))
    }

    func testUndefinedKeyDetectionCanBeDisabled() {
        XCTAssertEqual(matcher(undefined: false).classify("account.deletion.title"), .staticText)
    }

    func testKeyPathThatIsItselfADefinedEntryIsNotUndefined() {
        // Seeing a defined key's path verbatim on screen shouldn't happen
        // (the CMS would have resolved it), so it is not flagged as an
        // undefined backend key.
        XCTAssertEqual(matcher().classify("welcome.title"), .staticText)
    }

    func testPlainHardcodedTextIsStatic() {
        XCTAssertEqual(matcher().classify("Tap Me (hardcoded)"), .staticText)
    }

    func testSentenceWithDotsIsNotAKeyPath() {
        XCTAssertEqual(matcher().classify("This is hardcoded. Not a key."), .staticText)
    }

    func testEmptyIsStatic() {
        XCTAssertEqual(matcher().classify("   "), .staticText)
    }
}
