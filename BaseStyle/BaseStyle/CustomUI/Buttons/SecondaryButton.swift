//
//  SecondaryButton.swift
//  UI
//
//  Created by Amisha Italiya on 16/02/24.
//

import SwiftUI

public struct SecondaryButton: View {
    @StateObject private var loaderModel: LoaderViewModel = .init()

    private let text: String
    private let isEnabled: Bool = true
    private let showLoader: Bool
    private let onClick: (() -> Void)?

    public init(text: String, showLoader: Bool = false, onClick: (() -> Void)?) {
        self.text = text
        self.showLoader = showLoader
        self.onClick = onClick
    }

    public var body: some View {
        Button {
            if isEnabled && !showLoader {
                onClick?()
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    if showLoader {
                        ProgressView()
                            .scaleEffect(1, anchor: .center)
                            .progressViewStyle(CircularProgressViewStyle(tint: .mainPrimary.opacity(0.6)))
                            .opacity(loaderModel.isStillLoading ? 1 : 0)
                            .frame(width: !loaderModel.isStillLoading ? 0 : nil)
                            .animation(.default, value: loaderModel.isStillLoading)
                            .onAppear(perform: loaderModel.onViewAppear)
                    }

                    Text(text.localized)
                        .font(.buttonText())
                        .foregroundStyle(.mainPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 50)
            .clipShape(Capsule())
            .background(.clear)
            .cornerRadius(50)
            .minimumScaleFactor(0.5)
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(.mainPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.scale)
        .disabled(!isEnabled || showLoader)
        .opacity((isEnabled && !showLoader) ? 1 : 0.6)
    }
}
