//
//  Timestamp+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 25/04/24.
//

import Foundation
import FirebaseFirestore

extension Timestamp: Comparable {
    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.dateValue() < rhs.dateValue()
    }

    public static func > (lhs: Timestamp, rhs: Timestamp) -> Bool {
        return lhs.dateValue() > rhs.dateValue()
    }
}
