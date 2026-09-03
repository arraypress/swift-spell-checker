//
//  Misspelling.swift
//  SpellChecker
//

import Foundation

/// One word the dictionary does not contain, and where it is.
public struct Misspelling: Sendable, Codable, Equatable {

    /// The word as written.
    public let word: String
    /// UTF-16 offset into the text, which is what `NSRange` counts in.
    public let offset: Int
    /// Length in UTF-16 units.
    public let length: Int
    /// 1-based, so it matches what an editor shows.
    public let line: Int
    /// 1-based column, counted in Characters rather than UTF-16 units, so an
    /// emoji earlier in the line moves the column by one and not by two.
    public let column: Int
    /// The dictionary's alternatives, best first. Often empty for a name.
    public let suggestions: [String]
    /// The single replacement macOS would apply on its own, when it is
    /// confident enough to have one. Usually `suggestions.first`, sometimes
    /// nothing at all.
    public let correction: String?

    public init(word: String, offset: Int, length: Int, line: Int, column: Int,
                suggestions: [String], correction: String?) {
        self.word = word
        self.offset = offset
        self.length = length
        self.line = line
        self.column = column
        self.suggestions = suggestions
        self.correction = correction
    }
}
