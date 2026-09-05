//
//  SpellChecker.swift
//  SpellChecker
//
//  The system's own dictionaries — 44 languages on a Mac, already installed;
//  the same ones iOS uses. AppKit's NSSpellChecker on the Mac, UIKit's
//  UITextChecker everywhere else, behind one API.
//

import Foundation

/// Spell checking through the OS's own checker.
///
/// The dictionaries are the ones every app on the device uses: no download,
/// no network, no model. On the Mac `AppKit` is required but a running
/// `NSApplication` is not — this works from a plain command-line tool. On
/// iOS, tvOS, visionOS and Catalyst the same calls go through
/// `UITextChecker`; see ``check(_:language:suggestions:)`` for the two ways
/// that platform differs.
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

    /// The text with every confident correction applied, and what was changed.
    ///
    /// Only words the OS offers a `correction` for are touched. A word with
    /// several plausible alternatives and no clear winner — most names — is
    /// left exactly as it was, because a rewrite the author did not ask for
    /// is worse than a squiggle they can ignore.
    ///
    /// On iOS `UITextChecker` has no notion of a single confident correction,
    /// so ``Misspelling/correction`` is always nil there and this returns the
    /// text unchanged. Show ``Misspelling/suggestions`` instead.
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

    /// The words a prefix could become, best first — what a keyboard's
    /// suggestion strip shows as you type.
    ///
    /// Measured on macOS 27, en_GB: 2–19 ms a call, ordered by frequency
    /// (`th` → this, that, the, thanks), dialect-aware (`colou` → colourful;
    /// in en_US, `colo` → color). An unknown prefix returns nothing rather
    /// than guesses.
    ///
    /// - Parameter language: A dictionary code such as `en_GB`. `nil` uses
    ///   the checker's current language on the Mac and the current locale's
    ///   on iOS.
    public static func complete(_ prefix: String, language: String? = nil, limit: Int = 10) -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        return Array(Engine.completions(for: trimmed, language: language).prefix(limit))
    }

    /// Alternatives for a word that may be misspelled, best first — `recieve`
    /// → receive, relieve. Empty when the word is fine or nothing is close.
    public static func suggestions(for word: String, language: String? = nil, limit: Int = 5) -> [String] {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        return Array(Engine.guesses(for: trimmed, language: language).prefix(limit))
    }
}
