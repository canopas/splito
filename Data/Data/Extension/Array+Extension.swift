//
//  Array+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 23/04/24.
//

import Foundation

public extension Array where Element: Hashable {
    func uniqued() -> Array {
        var buffer = Array()
        var added = Set<Element>()

        for element in self where !added.contains(element) {
            buffer.append(element)
            added.insert(element)
        }

        return buffer
    }

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
