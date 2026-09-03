//
//  Replace.swift
//  SpellChecker
//
//  Applying a set of edits to a string without any of them moving the others.
//

import Foundation

/// One replacement, addressed by UTF-16 offset.
public struct Edit: Sendable, Equatable {
    public let offset: Int
    public let length: Int
    public let text: String

    public init(offset: Int, length: Int, text: String) {
        self.offset = offset
        self.length = length
        self.text = text
    }
}

/// Applying edits to text.
public enum Replace {

    /// Applies every edit, working back to front.
    ///
    /// Back to front because a replacement of a different length shifts every
    /// offset after it — fixing "definately" first would leave every later
    /// edit pointing two characters off.
    ///
    /// Edits landing outside the string are skipped rather than trapped: they
    /// arise when corrections found in one copy of a document are applied to
    /// another, which is exactly what masking code blocks does.
    public static func apply(_ edits: [Edit], to text: String) -> String {
        guard !edits.isEmpty else { return text }
        let result = NSMutableString(string: text)
        for edit in edits.sorted(by: { $0.offset > $1.offset }) {
            guard edit.offset >= 0, edit.length >= 0,
                  edit.offset + edit.length <= result.length else { continue }
            result.replaceCharacters(in: NSRange(location: edit.offset, length: edit.length),
                                     with: edit.text)
        }
        return result as String
    }
}
