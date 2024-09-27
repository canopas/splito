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
    private let height: CGFloat

    public init(tintColor: Color = primaryColor, height: CGFloat = 20) {
        self.tintColor = tintColor
        self.height = height
    }

    public var body: some View {
        ZStack(alignment: .center) {
            if viewModel.isStillLoading {
                Color.clear.ignoresSafeArea()

                JumpingDotsLoader(tintColor: tintColor)
                    .frame(height: height)
                    .padding()
            }
        }
        .onAppear(perform: viewModel.onViewAppear)
        .frame(alignment: .center)
    }
}

private struct JumpingDotsLoader: View {

    let tintColor: Color

    @State private var animate = [false, false, false]  // Array to manage multiple states

    private let jumpHeight: CGFloat = 10
    private let animationDuration: Double = 0.6
    private let dotCount = 3

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(tintColor)
                    .offset(y: animate[index] ? -jumpHeight : 0)
                    .animation(
                        Animation.easeInOut(duration: animationDuration)
                            .delay(Double(index) * 0.2)
                            .repeatForever(autoreverses: true),
                        value: animate[index]
                    )
            }
        }
        .onAppear {
            // Start animations for each dot with a delay
            for index in 0..<dotCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.2)) {
                    animate[index] = true
                }
            }
        }
    }
}

public struct ImageLoaderView: View {

    @StateObject var viewModel: LoaderViewModel = .init()

    private let tintColor: Color

    public init(tintColor: Color = secondaryText) {
        self.tintColor = tintColor
    }

    public var body: some View {
        ZStack {
            if viewModel.isStillLoading {
                ProgressView()
                    .scaleEffect(1, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
            }
        }
        .onAppear(perform: viewModel.onViewAppear)
    }
}
