//
//  Engine+UIKit.swift
//  SpellChecker
//
//  iOS, tvOS, visionOS and Catalyst: UITextChecker. The same dictionaries,
//  a smaller API — two honest differences are documented on `check`.
//

#if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst))
import Foundation
import UIKit

@MainActor
extension SpellChecker {

    /// The language codes with a dictionary installed, e.g. `en_GB`, `fr`.
    public static var languages: [String] {
        UITextChecker.availableLanguages
    }

    /// Every misspelling in the text.
    ///
    /// Two things differ from the Mac, and are not hidden:
    /// - `UITextChecker` cannot identify a language, so `nil` means the
    ///   current locale's dictionary (`en_GB` on a British device), not
    ///   "work it out". Pass a code for text in another language.
    /// - There is no "single confident correction" API, so
    ///   ``Misspelling/correction`` is always nil; ``suggestions`` carries
    ///   the alternatives, best first.
    public static func check(
        _ text: String,
        language: String? = nil,
        suggestions: Int = 3
    ) throws -> [Misspelling] {

        let code = try Engine.resolve(language)
        let checker = Engine.shared
        let string = text as NSString
        let positions = TextPosition(text)
        var found: [Misspelling] = []
        var offset = 0
        while offset < string.length {
            let range = checker.rangeOfMisspelledWord(in: text, range: NSRange(location: 0, length: string.length),
                                                      startingAt: offset, wrap: false, language: code)
            guard range.location != NSNotFound else { break }
            let guesses = suggestions > 0
                ? Array((checker.guesses(forWordRange: range, in: text, language: code) ?? []).prefix(suggestions))
                : []
            let position = positions.at(range.location)
            found.append(Misspelling(word: string.substring(with: range), offset: range.location, length: range.length,
                                     line: position.line, column: position.column,
                                     suggestions: guesses, correction: nil))
            offset = range.location + range.length
        }
        return found
    }

    // MARK: - The user's own dictionary

    /// Whether this word has been added to the user's dictionary.
    public static func knows(_ word: String) -> Bool { UITextChecker.hasLearnedWord(word) }

    /// Adds a word to the user's dictionary, so the system stops flagging it.
    public static func learn(_ word: String) { UITextChecker.learnWord(word) }

    /// Removes a word previously learned.
    public static func unlearn(_ word: String) { UITextChecker.unlearnWord(word) }
}

@MainActor
enum Engine {

    /// One checker for the process. `UITextChecker` loads dictionary state
    /// per instance; a fresh one per call measured 250 ms a completion on
    /// the iPhone 17 Pro simulator.
    static let shared = UITextChecker()

    /// A dictionary code `UITextChecker` will accept, or a clear error.
    static func resolve(_ language: String?) throws -> String {
        let available = UITextChecker.availableLanguages
        if let language {
            // Measured on the iPhone 17 Pro simulator: the list holds dialect
            // codes only — en_GB, en_US — and no bare "en". So: the exact code,
            // then its base (fr_CA → fr), then any dialect of it (en → en_GB).
            if available.contains(language) { return language }
            let base = language.split(separator: "_").first.map(String.init) ?? language
            if available.contains(base) { return base }
            if let dialect = available.first(where: { $0.hasPrefix(base + "_") }) { return dialect }
            throw SpellError.unknownLanguage(language, available: available)
        }
        let locale = Locale.current
        if let full = locale.identifier.split(separator: "@").first.map(String.init), available.contains(full) { return full }
        if let base = locale.language.languageCode?.identifier, available.contains(base) { return base }
        return available.first ?? "en"
    }

    static func completions(for prefix: String, language: String?) -> [String] {
        guard let code = try? resolve(language) else { return [] }
        let range = NSRange(location: 0, length: (prefix as NSString).length)
        return shared.completions(forPartialWordRange: range, in: prefix, language: code) ?? []
    }

    static func guesses(for word: String, language: String?) -> [String] {
        guard let code = try? resolve(language) else { return [] }
        let range = NSRange(location: 0, length: (word as NSString).length)
        return shared.guesses(forWordRange: range, in: word, language: code) ?? []
    }
}
#endif
