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
    private let showLoader: Bool
    private let onClick: (() -> Void)?
    
    public init(text: String, showLoader: Bool = false, onClick: (() -> Void)? = nil) {
        self.text = text
        self.showLoader = showLoader
        self.onClick = onClick
    }
    
    public var body: some View {
        Button {
            if !showLoader {
                onClick?()
            }
        } label: {
            HStack(spacing: 5) {
                if showLoader {
                    ProgressView()
                        .scaleEffect(1, anchor: .center)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryText))
                        .opacity(loaderModel.isStillLoading ? 1 : 0)
                        .frame(width: !loaderModel.isStillLoading ? 0 : nil)
                        .animation(.default, value: loaderModel.isStillLoading)
                        .onAppear(perform: loaderModel.onViewAppear)
                }
                
                Text(text)
                    .foregroundColor(.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 15)
            .minimumScaleFactor(0.5)
            .background(.orange)
            .clipShape(Capsule())
        }
        .frame(minHeight: 50)
        .buttonStyle(.scale)
        .disabled(showLoader)
    }
}
