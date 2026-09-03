//
//  TextPosition.swift
//  SpellChecker
//
//  Turning an offset into somewhere a person can look.
//

import Foundation

/// Maps UTF-16 offsets onto 1-based line and column numbers.
///
/// Built once per text and reused: the naïve form re-counts newlines from the
/// start for every result, which is quadratic over a document with a lot of
/// misspellings — exactly the document this gets pointed at.
public struct TextPosition: Sendable {

    /// The UTF-16 offset at which each line begins.
    private let lineStarts: [Int]
    private let text: String

    public init(_ text: String) {
        self.text = text
        var starts = [0]
        let string = text as NSString
        var index = 0
        while index < string.length {
            if string.character(at: index) == 10 { starts.append(index + 1) }
            index += 1
        }
        self.lineStarts = starts
    }

    /// The 1-based line and column of a UTF-16 offset.
    ///
    /// The column counts `Character`s, not UTF-16 units, so an emoji earlier
    /// in the line shifts the column by one — which is where a person's eye
    /// says the word is.
    public func at(_ offset: Int) -> (line: Int, column: Int) {
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        let start = lineStarts[low]
        let string = text as NSString
        let prefix = string.substring(with: NSRange(location: start,
                                                    length: max(0, min(offset, string.length) - start)))
        return (low + 1, prefix.count + 1)
    }
}
