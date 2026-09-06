//
//  SpellError.swift
//  SpellChecker
//

import Foundation

/// Why text could not be checked.
public enum SpellError: Error, LocalizedError, Equatable {

    /// A language code no dictionary is installed for.
    case unknownLanguage(String, available: [String])
    /// The file could not be read as text.
    case unreadable(String)

    /// A one-line reason, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case let .unknownLanguage(code, available):
            return "no dictionary for \(code) — installed: \(available.joined(separator: " "))"
        case let .unreadable(path):
            return "could not read \(path) as text"
        }
    }
}
