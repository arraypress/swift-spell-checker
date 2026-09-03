//
//  SpellChecker.swift
//  SpellChecker
//
//  macOS's own dictionaries — 44 languages, already installed.
//

import AppKit
import Foundation

/// Spell checking through `NSSpellChecker`.
///
/// The dictionaries are the ones every Mac app uses, already on the machine:
/// no download, no network, no model. `AppKit` is required but a running
/// `NSApplication` is not — this works from a plain command-line tool.
///
/// ## Grammar is not here on purpose
///
/// `NSSpellChecker` exposes grammar checking, and on macOS 27 it **finds
/// nothing**: measured across six blatantly ungrammatical sentences, in four
/// language settings, through both `checkGrammar` and the `.grammar`
/// checking type — zero results every time. Apple ships no grammar plugin;
/// the API is a hook for one. Reporting "no grammar problems" from that would
/// be a lie told confidently, so this type does not offer it.
@MainActor
public enum SpellChecker {

    /// The language codes with a dictionary installed, e.g. `en_GB`, `fr`.
    public static var languages: [String] {
        NSSpellChecker.shared.availableLanguages
    }

    /// Every misspelling in the text.
    ///
    /// - Parameter language: `nil` — the default — lets macOS identify the
    ///   language itself, which is both accurate and the safe choice. Pinning
    ///   the **wrong** language does not fail; it floods. Measured: pinning
    ///   `fr` on a Spanish sentence flags six ordinary Spanish words, and
    ///   pinning `es` on English flags "also". Pass one only when the text is
    ///   short enough that identification has little to work with, or when
    ///   the dialect matters — `en_US` flags "colour", `en_GB` does not.
    /// - Parameter suggestions: how many alternatives to fetch per word.
    ///   Zero skips the lookup, which is the expensive part.
    public static func check(
        _ text: String,
        language: String? = nil,
        suggestions: Int = 3
    ) throws -> [Misspelling] {

        let checker = NSSpellChecker.shared

        /// The checker's language is process-wide state rather than a
        /// parameter, so it is restored afterwards — otherwise one call with
        /// `--language de` quietly changes the answer the next one gives.
        let previousLanguage = checker.language()
        let previouslyAutomatic = checker.automaticallyIdentifiesLanguages
        defer {
            checker.automaticallyIdentifiesLanguages = previouslyAutomatic
            _ = checker.setLanguage(previousLanguage)
        }

        if let language {
            checker.automaticallyIdentifiesLanguages = false
            /// `setLanguage` is the gate rather than `availableLanguages`,
            /// because it accepts more than that list names: `en_US` and
            /// `fr_CA` are both taken (resolving to `en` and `fr`) and
            /// neither appears in it. It returns false for a code no
            /// dictionary answers to, which is the question actually being
            /// asked.
            guard checker.setLanguage(language) else {
                throw SpellError.unknownLanguage(language, available: checker.availableLanguages)
            }
        } else {
            checker.automaticallyIdentifiesLanguages = true
        }

        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: tag) }

        let string = text as NSString
        let results = checker.check(
            text, range: NSRange(location: 0, length: string.length),
            types: NSTextCheckingResult.CheckingType.spelling.rawValue,
            options: nil, inSpellDocumentWithTag: tag, orthography: nil, wordCount: nil)

        let positions = TextPosition(text)
        return results.map { result in
            let word = string.substring(with: result.range)
            /// `language: nil` throughout: with automatic identification on,
            /// passing an explicit code here returns an empty list instead of
            /// an error, so the alternatives silently vanish.
            let guesses = suggestions > 0
                ? Array((checker.guesses(forWordRange: result.range, in: text,
                                         language: nil, inSpellDocumentWithTag: tag) ?? [])
                    .prefix(suggestions))
                : []
            let position = positions.at(result.range.location)
            return Misspelling(
                word: word,
                offset: result.range.location,
                length: result.range.length,
                line: position.line,
                column: position.column,
                suggestions: guesses,
                correction: checker.correction(forWordRange: result.range, in: text,
                                               language: checker.language(),
                                               inSpellDocumentWithTag: tag))
        }
    }

    /// The text with every confident correction applied, and what was changed.
    ///
    /// Only words macOS offers a `correction` for are touched. A word with
    /// several plausible alternatives and no clear winner — most names — is
    /// left exactly as it was, because a rewrite the author did not ask for
    /// is worse than a squiggle they can ignore.
    public static func corrected(
        _ text: String,
        language: String? = nil
    ) throws -> (text: String, applied: [Misspelling]) {

        let found = try check(text, language: language, suggestions: 1)
        let applied = found.filter { $0.correction != nil }
        return (Replace.apply(edits(for: applied), to: text), applied)
    }

    /// The edits a set of misspellings implies.
    ///
    /// Separate from ``corrected(_:language:)`` so a caller can **find** in
    /// one copy of a document and **apply** to another. That is not a
    /// contrivance: checking a README means blanking its code blocks first,
    /// and the corrected file has to be the original with the code still in
    /// it. Masking preserves every offset, so the edits transfer exactly.
    public static func edits(for misspellings: [Misspelling]) -> [Edit] {
        misspellings.compactMap { misspelling in
            misspelling.correction.map {
                Edit(offset: misspelling.offset, length: misspelling.length, text: $0)
            }
        }
    }

    // MARK: - The user's own dictionary

    /// Whether this word has been added to the user's dictionary.
    public static func knows(_ word: String) -> Bool {
        NSSpellChecker.shared.hasLearnedWord(word)
    }

    /// Adds a word to the user's dictionary — the same one the Spelling panel
    /// writes to, so every app on the Mac stops flagging it.
    public static func learn(_ word: String) {
        NSSpellChecker.shared.learnWord(word)
    }

    /// Removes a word previously learned.
    public static func unlearn(_ word: String) {
        NSSpellChecker.shared.unlearnWord(word)
    }
}
