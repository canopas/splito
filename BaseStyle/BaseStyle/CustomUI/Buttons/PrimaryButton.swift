//
//  PrimaryButton.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import Foundation
import SwiftUI

public struct PrimaryButton: View {

    @StateObject var loaderModel: LoaderViewModel = .init()

    private let text: String
    private let isEnabled: Bool
    private let showLoader: Bool
    private let onClick: (() -> Void)?

    private var color: Color {
        return isEnabled ? primaryColor : primaryColor.opacity(0.6)
    }

    private var textColor: Color {
        return (isEnabled && !showLoader) ? primaryDarkText : primaryDarkText.opacity(0.6)
    }

    public init(text: String, isEnabled: Bool = true, showLoader: Bool = false, onClick: (() -> Void)? = nil) {
        self.text = text
        self.isEnabled = isEnabled
        self.showLoader = showLoader
        self.onClick = onClick
    }

    public var body: some View {
        Button {
            if isEnabled && !showLoader {
                onClick?()
            }
        } label: {
            HStack(spacing: 5) {
                if showLoader {
                    ProgressView()
                        .scaleEffect(1, anchor: .center)
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .opacity(loaderModel.isStillLoading ? 1 : 0)
                        .frame(width: !loaderModel.isStillLoading ? 0 : nil)
                        .animation(.default, value: loaderModel.isStillLoading)
                        .onAppear(perform: loaderModel.onViewAppear)
                }

                Text(text)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 15)
            .minimumScaleFactor(0.5)
            .background(color)
            .clipShape(Capsule())
        }
        .frame(minHeight: 50)
        .buttonStyle(.scale)
        .disabled(!isEnabled || showLoader)
        .opacity((isEnabled && !showLoader) ? 1 : 0.6)
    }
}
