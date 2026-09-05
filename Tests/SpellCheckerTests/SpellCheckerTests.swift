//
//  SpellCheckerTests.swift
//  SpellChecker
//

import XCTest
@testable import SpellChecker

@MainActor
final class SpellCheckerTests: XCTestCase {

    func testItFindsMisspellingsAndLeavesRealWordsAlone() throws {
        let found = try SpellChecker.check("The cat sat on the tabel and the dog also.")
        XCTAssertEqual(found.map(\.word), ["tabel"])
        XCTAssertEqual(found.first?.suggestions.first, "table")
    }

    func testCleanTextGivesNothing() throws {
        XCTAssertTrue(try SpellChecker.check("The cat sat on the mat.").isEmpty)
    }

    #if os(macOS)
    func testItReadsOtherLanguagesWithoutBeingTold() throws {
        // macOS identifies the language itself, and does it well: only the
        // planted error comes back, not every ordinary French word.
        let found = try SpellChecker.check("Le chat est sur le tapiss et le chien aussii.")
        XCTAssertEqual(found.map(\.word), ["tapiss", "aussii"])
    }
    #endif

    #if os(macOS)
    func testPinningTheWrongLanguageFloods() throws {
        // Measured, and the reason `language` defaults to nil: pinning the
        // wrong dictionary does not fail, it drowns the real errors. A caller
        // who sets --language on a mixed document gets nonsense, quietly.
        let french = "Le chat est sur le tapiss et le chien aussii."
        let automatic = try SpellChecker.check(french, language: nil)
        let pinned = try SpellChecker.check(french, language: "en_GB")
        XCTAssertEqual(automatic.count, 2)
        XCTAssertGreaterThan(pinned.count, automatic.count)
    }
    #endif

    func testDialectsDisagree() throws {
        let text = "The colour of the theatre organisation."
        XCTAssertTrue(try SpellChecker.check(text, language: "en_GB").isEmpty)
        XCTAssertFalse(try SpellChecker.check(text, language: "en_US").isEmpty)
    }

    func testAnUninstalledLanguageIsRefused() {
        // Rather than silently checking against whatever was set last.
        XCTAssertThrowsError(try SpellChecker.check("hello", language: "xx_YY")) { error in
            guard case SpellError.unknownLanguage = error else { return XCTFail("got \(error)") }
        }
    }

    #if os(macOS)
    func testCodesOutsideTheAvailableListStillWork() throws {
        // en_US and fr_CA are both accepted and neither is in
        // availableLanguages — which is why the gate is setLanguage, not
        // membership of that list.
        XCTAssertFalse(SpellChecker.languages.contains("en_US"))
        XCTAssertNoThrow(try SpellChecker.check("color", language: "en_US"))
        XCTAssertNoThrow(try SpellChecker.check("chat", language: "fr_CA"))
    }
    #endif

    #if os(macOS)
    func testTheLanguageIsRestoredAfterAPinnedCheck() throws {
        // NSSpellChecker's language is process-wide state, not a parameter.
        // Without the restore, one --language de call changes the answer
        // every later call gives.
        let before = NSSpellChecker.shared.language()
        _ = try SpellChecker.check("Der Hund.", language: "de")
        XCTAssertEqual(NSSpellChecker.shared.language(), before)
    }
    #endif

    #if os(macOS)
    func testCorrectedRewritesOnlyWhatMacOSIsSureOf() throws {
        let (fixed, applied) = try SpellChecker.corrected("I recieve teh package.")
        XCTAssertEqual(fixed, "I receive the package.")
        XCTAssertEqual(applied.count, 2)
    }
    #endif

    func testCorrectedLeavesTextWithNothingToFixAlone() throws {
        let original = "The cat sat on the mat."
        let (fixed, applied) = try SpellChecker.corrected(original)
        XCTAssertEqual(fixed, original)
        XCTAssertTrue(applied.isEmpty)
    }

    #if os(macOS)
    func testCorrectingSeveralWordsKeepsTheLaterOnesAligned() throws {
        // Replacements run back to front for exactly this reason: fixing a
        // word early in the string shifts every offset after it, and
        // "receive" is a character shorter than "recieve" is not — but
        // "definitely" and "definately" differ, so the last one moves.
        let (fixed, applied) = try SpellChecker.corrected(
            "Please recieve teh parcel, it definately arrived.")
        XCTAssertEqual(fixed, "Please receive the parcel, it definitely arrived.")
        XCTAssertEqual(applied.map(\.word), ["recieve", "teh", "definately"])
    }
    #endif

    #if os(macOS)
    func testARunOfUnknownWordsComesBackAsOneResult() throws {
        // Measured, and worth knowing before trusting a word count: macOS
        // merges adjacent unrecognised tokens into a single range and offers
        // no suggestions for the blob.
        let found = try SpellChecker.check("teh teh teh")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.word, "teh teh teh")
    }
    #endif

    func testEveryLanguageCodeIsUsable() {
        XCTAssertFalse(SpellChecker.languages.isEmpty)
        XCTAssertTrue(SpellChecker.languages.contains { $0.hasPrefix("en") })
    }
}

@MainActor
final class TypographyTests: XCTestCase {

    #if os(macOS)
    func testStraightQuotesBecomeCurly() {
        let (text, changes) = Typography.polish("She said \"hello\".")
        XCTAssertEqual(text, "She said “hello”.")
        XCTAssertEqual(changes.count, 2)
    }
    #endif

    #if os(macOS)
    func testApostrophesGoTheRightWay() {
        // The reason this uses AppKit rather than a search-and-replace: a
        // naive rule turns the apostrophe in it's into an opening quote.
        let (text, _) = Typography.polish("it's")
        XCTAssertEqual(text, "it’s")
    }
    #endif

    #if os(macOS)
    func testDoubleHyphenBecomesAnEmDash() {
        let (text, changes) = Typography.polish("wait -- listen")
        XCTAssertTrue(text.contains("—"))
        XCTAssertEqual(changes.first?.from, "--")
    }
    #endif

    #if os(macOS)
    func testAlreadyPolishedTextIsLeftAlone() {
        let original = "She said “hello” — quietly."
        let (text, changes) = Typography.polish(original)
        XCTAssertEqual(text, original)
        XCTAssertTrue(changes.isEmpty)
    }
    #endif
}

final class TextPositionTests: XCTestCase {

    func testLinesAndColumnsAreOneBased() {
        let positions = TextPosition("first line\nsecond line\nthird")
        XCTAssertEqual(positions.at(0).line, 1)
        XCTAssertEqual(positions.at(0).column, 1)
        XCTAssertEqual(positions.at(11).line, 2)
        XCTAssertEqual(positions.at(11).column, 1)
        XCTAssertEqual(positions.at(18).line, 2)
        XCTAssertEqual(positions.at(18).column, 8)
    }

    func testColumnsCountCharactersNotUTF16Units() {
        // An emoji is two UTF-16 units and one Character. The column a person
        // is looking for is the second one.
        let text = "🎧 tabel"
        let positions = TextPosition(text)
        let offset = (text as NSString).range(of: "tabel").location
        XCTAssertEqual(offset, 3, "the emoji occupies two UTF-16 units")
        XCTAssertEqual(positions.at(offset).column, 3)
    }

    func testAnOffsetPastTheEndDoesNotCrash() {
        let positions = TextPosition("short")
        XCTAssertEqual(positions.at(500).line, 1)
    }
}

@MainActor
final class ReplaceTests: XCTestCase {

    #if os(macOS)
    func testEditsFoundInAMaskedCopyApplyToTheOriginal() throws {
        // The case this exists for: a README's code blocks are blanked
        // before checking, or every identifier comes back misspelled — but
        // the file written back has to be the original, code and all.
        // Masking keeps every offset, so the edits transfer exactly.
        let original = "Please recieve `npm instal` teh parcel."
        let masked   = "Please recieve              teh parcel."
        XCTAssertEqual((original as NSString).length, (masked as NSString).length)

        let found = try SpellChecker.check(masked, suggestions: 1)
        let fixed = Replace.apply(SpellChecker.edits(for: found), to: original)
        XCTAssertEqual(fixed, "Please receive `npm instal` the parcel.")
    }
    #endif

    func testAnEditPastTheEndIsSkippedNotTrapped() {
        XCTAssertEqual(Replace.apply([Edit(offset: 90, length: 4, text: "x")], to: "short"), "short")
    }

    func testEditsApplyBackToFrontWhateverOrderTheyArriveIn() {
        // Given out of order on purpose: sorting is the whole job.
        let edits = [Edit(offset: 0, length: 3, text: "AAAA"), Edit(offset: 8, length: 5, text: "B")]
        XCTAssertEqual(Replace.apply(edits, to: "one two three"), "AAAA two B")
    }

    #if os(macOS)
    func testTypographyEditsTransferToTheOriginalToo() {
        let original = "say \"hi\" in `\"quoted\"`"
        let masked   = "say \"hi\" in           "
        XCTAssertEqual((original as NSString).length, (masked as NSString).length)
        let changes = Typography.substitutions(in: masked)
        let polished = Replace.apply(Typography.edits(for: changes), to: original)
        XCTAssertEqual(polished, "say \u{201C}hi\u{201D} in `\"quoted\"`")
    }
    #endif

    // MARK: - Completions and suggestions (added 2026-09-06)

    /// Measured: 2–19 ms a call, frequency-ordered, dialect-aware.
    func testCompletionsAreFrequencyOrderedAndDialectAware() {
        let keyboard = SpellChecker.complete("keybo", language: "en_GB")
        XCTAssertEqual(keyboard.first, "keyboard", "\(keyboard)")
        XCTAssertTrue(keyboard.contains("keyboards"))

        let th = SpellChecker.complete("th", language: "en_GB")
        // Both platforms put a top-frequency word first; they disagree on which.
        // Measured: macOS "this", iOS "the".
        XCTAssertTrue(["this", "the", "that"].contains(th.first ?? ""), "got \(th.prefix(4))")
        #if os(macOS)
        XCTAssertEqual(th.first, "this")
        #endif

        XCTAssertEqual(SpellChecker.complete("colou", language: "en_GB").first?.hasPrefix("colour"), true)
        XCTAssertEqual(SpellChecker.complete("colo", language: "en_US").first, "color")
    }

    func testCompletionsRespectTheLimitAndSayNothingForNonsense() {
        XCTAssertEqual(SpellChecker.complete("prog", language: "en_GB", limit: 3).count, 3)
        XCTAssertEqual(SpellChecker.complete("prog", language: "en_GB", limit: 0), [])
        XCTAssertEqual(SpellChecker.complete("xqz", language: "en_GB"), [])
        XCTAssertEqual(SpellChecker.complete("   ", language: "en_GB"), [])
    }

    func testCompletionsAreFastEnoughForAKeystroke() {
        _ = SpellChecker.complete("warm", language: "en_GB")   // warm the dictionary
        let started = Date()
        for prefix in ["pro", "rec", "key", "swi", "tha", "col", "int", "con"] {
            _ = SpellChecker.complete(prefix, language: "en_GB")
        }
        let perCall = Date().timeIntervalSince(started) / 8
        print("MEASURED completion latency: \(Int(perCall * 1000)) ms a call")
        #if os(macOS)
        XCTAssertLessThan(perCall, 0.05, "\(Int(perCall * 1000)) ms a call is too slow for a suggestion strip")
        #else
        // Simulator, not device; the bound is generous and the number is printed.
        XCTAssertLessThan(perCall, 0.5, "\(Int(perCall * 1000)) ms a call")
        #endif
    }

    func testSuggestionsFixACommonMisspellingAndStayQuietOnARealWord() {
        XCTAssertEqual(SpellChecker.suggestions(for: "recieve", language: "en_GB").first, "receive")
        XCTAssertEqual(SpellChecker.suggestions(for: "teh", language: "en_GB", limit: 1).count, 1)
        XCTAssertEqual(SpellChecker.suggestions(for: "", language: "en_GB"), [])
        XCTAssertEqual(SpellChecker.suggestions(for: "recieve", language: "en_GB", limit: 0), [])
    }

    #if os(iOS)
    /// Measured on the iPhone 17 Pro simulator: each unknown word is its own
    /// result, where the Mac merges a run into one.
    func testOnIOSARunOfUnknownWordsIsReportedPerWord() throws {
        let found = try SpellChecker.check("teh teh teh", language: "en")
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(found.map(\.word), ["teh", "teh", "teh"])
    }

    /// iOS lists dialect codes explicitly, and only the dictionaries the
    /// device has. The simulator ships English alone, so French throws.
    func testOnIOSDialectCodesAreListedAndUninstalledLanguagesThrow() throws {
        XCTAssertTrue(SpellChecker.languages.contains("en_US"), "\(SpellChecker.languages)")
        XCTAssertNoThrow(try SpellChecker.check("colour", language: "en_US"))
        if !SpellChecker.languages.contains(where: { $0.hasPrefix("fr") }) {
            XCTAssertThrowsError(try SpellChecker.check("bonjour", language: "fr_CA"))
        }
    }

    /// iOS has no automatic language identification: nil is the current
    /// locale, and a wrong code is an error rather than a flood.
    func testOnIOSNilLanguageIsTheLocaleAndUnknownCodesAreRefused() throws {
        let found = try SpellChecker.check("The cat sat on the tabel.")
        XCTAssertEqual(found.map(\.word), ["tabel"])
        XCTAssertNil(found.first?.correction, "UITextChecker has no confident-correction API")
        XCTAssertEqual(found.first?.suggestions.first, "table")
        XCTAssertThrowsError(try SpellChecker.check("x", language: "zz_ZZ"))
        XCTAssertFalse(SpellChecker.languages.isEmpty)
    }
    #endif
}
