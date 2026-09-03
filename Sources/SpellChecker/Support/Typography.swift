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
        var changes: [Change] = []
        let output = NSMutableString(string: text)
        /// Back to front, so earlier offsets stay valid as the string shifts.
        for result in results.reversed() {
            guard let replacement = result.replacementString else { continue }
            let original = string.substring(with: result.range)
            guard original != replacement else { continue }
            output.replaceCharacters(in: result.range, with: replacement)
            let position = positions.at(result.range.location)
            changes.insert(Change(from: original, to: replacement, offset: result.range.location,
                                  line: position.line, column: position.column), at: 0)
        }
        return (output as String, changes)
    }
}
