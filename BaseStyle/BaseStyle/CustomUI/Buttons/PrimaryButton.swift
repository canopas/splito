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
    private var bgColor: Color
    private var textColor: Color
    private let isEnabled: Bool
    private let showLoader: Bool

    private let onClick: (() -> Void)?

    public init(text: String, textColor: Color = primaryLightText, bgColor: Color = primaryColor,
                isEnabled: Bool = true, showLoader: Bool = false, onClick: (() -> Void)? = nil) {
        self.text = text
        self.textColor = textColor
        self.bgColor = bgColor
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

                Text(text.localized)
                    .font(.buttonText())
                    .foregroundStyle(isEnabled ? textColor : textColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 15)
            .minimumScaleFactor(0.5)
            .background(isEnabled ? bgColor : bgColor.opacity(0.6))
            .cornerRadius(12)
        }
        .frame(minHeight: 50)
        .buttonStyle(.scale)
        .disabled(!isEnabled || showLoader)
    }
}
