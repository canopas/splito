//
//  AlertPrompt.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import Foundation
import SwiftUI

public struct AlertPrompt {
    public let title: String
    public let message: String
    public var positiveBtnTitle: String?
    public var positiveBtnAction: (() -> Void)?
    public var negativeBtnTitle: String?
    public var negativeBtnAction: (() -> Void)?
    public var isPositiveBtnDestructive: Bool = false

    public init(title: String = "", message: String, positiveBtnTitle: String? = nil, positiveBtnAction: (() -> Void)? = nil, negativeBtnTitle: String? = nil, negativeBtnAction: (() -> Void)? = nil, isPositiveBtnDestructive: Bool = false) {
        self.title = title
        self.message = message
        self.positiveBtnTitle = positiveBtnTitle
        self.positiveBtnAction = positiveBtnAction
        self.negativeBtnTitle = negativeBtnTitle
        self.negativeBtnAction = negativeBtnAction
        self.isPositiveBtnDestructive = isPositiveBtnDestructive
    }
}

public struct Backport<Content> {
    public let content: Content

    public init(content: Content) {
        self.content = content
    }
}

public extension View {
    var backport: Backport<Self> { Backport(content: self) }
}

public extension Backport where Content: View {
    @ViewBuilder func alert(isPresented: Binding<Bool>, alertStruct: AlertPrompt) -> some View {
        content
            .alert(alertStruct.title.localized, isPresented: isPresented) {
                if let positiveTitle = alertStruct.positiveBtnTitle {
                    Button(positiveTitle.localized, role: alertStruct.isPositiveBtnDestructive ? .destructive : nil, action: {
                        alertStruct.positiveBtnAction?()
                    })
                }
                if let negativeTitle = alertStruct.negativeBtnTitle {
                    Button(negativeTitle.localized, role: .cancel, action: {
                        alertStruct.negativeBtnAction?()
                    })
                }
                if alertStruct.positiveBtnTitle == nil && alertStruct.negativeBtnTitle == nil {
                    Button("Ok", role: .cancel, action: {
                        isPresented.wrappedValue = false
                    })
                }
            } message: {
                Text(alertStruct.message.localized)
            }
    }
}
