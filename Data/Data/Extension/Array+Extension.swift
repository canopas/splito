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

    /// Perform asynchronous operations: converting the mapping process to run asynchronously with the help of Task and await inside the map.
    func concurrentMap<T>(_ transform: @escaping (Element) async -> T) async -> [T] {
        await withTaskGroup(of: T.self) { group in
            for element in self {
                group.addTask { await transform(element) }
            }

            var results = [T]()
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
