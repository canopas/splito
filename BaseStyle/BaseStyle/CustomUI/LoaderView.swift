//
//  LoaderView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import SwiftUI

public struct LoaderView: View {
    @StateObject private var viewModel: LoaderViewModel = .init()

    private let tintColor: Color
    private let scaleSize: CGFloat
    private let withDarkBG: Bool
    private let showLoader: Bool

    public init(tintColor: Color = primaryColor, scaleSize: CGFloat = 2.0, withDarkBg: Bool = false, showLoader: Bool = false) {
        self.tintColor = tintColor
        self.scaleSize = scaleSize
        self.withDarkBG = withDarkBg
        self.showLoader = showLoader
    }

    public var body: some View {
        ZStack {
            if viewModel.isStillLoading {
                if withDarkBG {
                    surfaceDarkColor.opacity(0.05)
                        .ignoresSafeArea()
                } else {
                    Color.clear.ignoresSafeArea()
                }

                ProgressView()
                    .scaleEffect(scaleSize, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
            }
        }
        .onAppear {
            viewModel.onViewAppear()
        }
    }
}

public struct ImageLoaderView: View {
    @StateObject var viewModel: LoaderViewModel = .init()

    public init() { }

    public var body: some View {
        ZStack {
            if viewModel.isStillLoading {
                ProgressView()
                    .scaleEffect(1, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: secondaryText))
            }
        }
        .onAppear(perform: viewModel.onViewAppear)
    }
}

public struct LoaderCellView: View {
    private var tintColor: Color
    private var isLoading: Bool

    public init(tintColor: Color = secondaryText, isLoading: Bool = false) {
        self.tintColor = tintColor
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(spacing: 0) {
            Color.clear.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .scaleEffect(anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
            }
        }
        .frame(height: 40)
    }
}
