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

    private let totalDots = 7
    private let timer = Timer.publish(every: 0.20, on: .main, in: .common).autoconnect()

    @State var current = 0

    public init(tintColor: Color = primaryColor, height: CGFloat = 38) {
        self.tintColor = tintColor
        self.height = height
    }

    public var body: some View {
        ZStack {
            if viewModel.isStillLoading {
                Color.clear.ignoresSafeArea()

                ForEach(0..<totalDots, id: \.self) { index in
                    Circle()
                        .fill(tintColor)
                        .frame(height: height / 4)
                        .frame(height: height, alignment: .top)
                        .rotationEffect(Angle(degrees: 360 / Double(totalDots) * Double(index)))
                        .opacity(current == index ? 1.0 : current == index + 1 ? 0.5 :
                                    current == (totalDots - 1) && index == (totalDots - 1) ? 0.5 : 0)
                }
            }
        }
        .onAppear(perform: viewModel.onViewAppear)
        .onReceive(timer, perform: { _ in
            withAnimation(Animation.easeInOut(duration: 0.5).repeatCount(1, autoreverses: true)) {
                current = current == (totalDots - 1) ? 0 : current + 1
            }
        })
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
