//
//  ToastPrompt.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import SwiftUI

public enum ToastStyle {
    case error
    case warning
    case success
    case info
}

public extension ToastStyle {
    var themeColor: Color {
        switch self {
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color.blue
        case .success: return Color.green
        }
    }

    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

public struct ToastPrompt: Equatable {

    public static func == (lhs: ToastPrompt, rhs: ToastPrompt) -> Bool {
        return lhs.type == rhs.type && lhs.title == rhs.title && lhs.message == rhs.message && lhs.duration == rhs.duration
    }

    public let type: ToastStyle
    public let title: String
    public let message: String
    public let duration: Double
    public let onDismiss: (() -> Void)?

    public init(type: ToastStyle, title: String, message: String, duration: Double = 3, onDismiss: (() -> Void)? = nil) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.onDismiss = onDismiss
    }
}
