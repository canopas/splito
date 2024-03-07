//
//  AppRoute.swift
//  Data
//
//  Created by Amisha Italiya on 27/02/24.
//

import Foundation

public enum AppRoute: Hashable {

    public static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        return lhs.key == rhs.key
    }

    // MARK: - Friends Tab
    case FriendsHome

    // MARK: - Groups Tab
    case GroupHome
    case CreateGroup

    // MARK: - Activity Tab
    case ActivityHome

    // MARK: - Account Tab
    case AccountHome

    var key: String {
        switch self {
        case .FriendsHome:
            "home"

        case .ActivityHome:
            "activityHome"

        case .GroupHome:
            "groupHome"
        case .CreateGroup:
            "createGroup"

        case .AccountHome:
            "accountHome"
        }
    }
}
