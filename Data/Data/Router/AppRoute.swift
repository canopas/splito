//
//  AppRoute.swift
//  Data
//
//  Created by Amisha Italiya on 27/02/24.
//

import Foundation

public enum AppRoute: Hashable {
    case Home
    case Profile

    var key: String {
        switch self {
        case .Home:
            "home"
        case .Profile:
            "profile"
        }
    }
}
