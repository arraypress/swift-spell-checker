//
//  Edit.swift
//  SpellChecker
//
//  Applying a set of edits to a string without any of them moving the others.
//

//

import Foundation

/// One replacement, addressed by UTF-16 offset.
public struct Edit: Sendable, Equatable {
    /// Where the replacement starts, in UTF-16 units.
    public let offset: Int
    /// How many UTF-16 units it replaces.
    public let length: Int
    /// What goes in their place.
    public let text: String

    public init(offset: Int, length: Int, text: String) {
        self.offset = offset
        self.length = length
        self.text = text
    }
}
