//
//  DeepLinkManager.swift
//  Data
//
//  Created by Amisha Italiya on 27/12/24.
//

import Foundation

public enum DeepLinkType: Equatable {
    case group(groupId: String)

    var key: String {
        switch self {
        case .group:
            return "group"
        }
    }
}

public class DeepLinkManager: ObservableObject {

    @Published public var type: DeepLinkType?

    public init() {}

    public func handleDeepLink(_ url: URL) {
        let urlString = url.deletingLastPathComponent().absoluteString

        switch urlString {
        case Constants.groupBaseUrl:
            type = .group(groupId: url.lastPathComponent)
        default:
            type = nil
        }
    }
}
