//
//  Typography.swift
//  SpellChecker
//
//  The substitutions a Mac makes as you type, applied to text that was
//  written somewhere else.
//

import AppKit
import Foundation

/// Straight quotes to curly, double hyphens to em dashes.
///
/// The same `NSTextCheckingResult` machinery behind "Smart Quotes" in every
/// Mac text field, which is why it gets apostrophes right in `it's` and
/// `'90s` where a search-and-replace gets them backwards.
@MainActor
public enum Typography {

    /// One substitution that was made.
    public struct Change: Sendable, Codable, Equatable {
        public let from: String
        public let to: String
        public let offset: Int
        public let line: Int
        public let column: Int
    }

    /// Applies smart quotes and dashes.
    public static func polish(_ text: String) -> (text: String, changes: [Change]) {
        let changes = substitutions(in: text)
        return (Replace.apply(edits(for: changes), to: text), changes)
    }

    /// The edits a set of changes implies, so a caller can find them in a
    /// masked copy of a document and apply them to the original — curly
    /// quotes inside a code fence would break the code.
    public static func edits(for changes: [Change]) -> [Edit] {
        changes.map {
            Edit(offset: $0.offset, length: ($0.from as NSString).length, text: $0.to)
        }
    }

    /// The substitutions macOS would make, without making them.
    public static func substitutions(in text: String) -> [Change] {
        let checker = NSSpellChecker.shared
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: tag) }

        let string = text as NSString
        let results = checker.check(
            text, range: NSRange(location: 0, length: string.length),
            types: NSTextCheckingResult.CheckingType.quote.rawValue
                 | NSTextCheckingResult.CheckingType.dash.rawValue,
            options: nil, inSpellDocumentWithTag: tag, orthography: nil, wordCount: nil)

        let positions = TextPosition(text)
        return results.compactMap { result in
            guard let replacement = result.replacementString else { return nil }
            let original = string.substring(with: result.range)
            guard original != replacement else { return nil }
            let position = positions.at(result.range.location)
            return Change(from: original, to: replacement, offset: result.range.location,
                          line: position.line, column: position.column)
        }
    }
}
