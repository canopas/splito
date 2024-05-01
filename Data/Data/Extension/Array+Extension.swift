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

        for element in self {
            if !added.contains(element) {
                buffer.append(element)
                added.insert(element)
            }
        }

        return buffer
    }
}
