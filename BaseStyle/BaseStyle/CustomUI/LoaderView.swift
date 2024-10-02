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

    public init(tintColor: Color = primaryColor, height: CGFloat = 8) {
        self.tintColor = tintColor
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.isStillLoading {
                    Color.clear.ignoresSafeArea()

                    DotsAnimation(color: tintColor, height: height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center the loader by using the size from GeometryReader
                }
            }
        }
        .onAppear(perform: viewModel.onViewAppear)
    }
}

private struct DotsAnimation: View {

    let color: Color
    let height: CGFloat

    static let DATA: [AnimationData] = [
        AnimationData(delay: 0.0, ty: -20),
        AnimationData(delay: 0.1, ty: -24),
        AnimationData(delay: 0.2, ty: -28)
    ]

    @State var transY: [CGFloat] = DATA.map { _ in return 0 }

    var animation = Animation.easeInOut.speed(0.5)

    var body: some View {
        HStack(spacing: 5) {
            DotView(transY: $transY[0], color: color, height: height)
            DotView(transY: $transY[1], color: color, height: height)
            DotView(transY: $transY[2], color: color, height: height)
        }
        .onAppear {
            animateDots()
        }
    }

    func animateDots() {
        // Go through animation data and start each
        // animation delayed as per data
        for (index, data) in DotsAnimation.DATA.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + data.delay) {
                animateDot(binding: $transY[index], animationData: data)
            }
        }

        // Repeat main loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            animateDots()
        }
    }

    func animateDot(binding: Binding<CGFloat>, animationData: AnimationData) {
        withAnimation(animation) {
            binding.wrappedValue = animationData.ty
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                binding.wrappedValue = 0
            }
        }
    }
}

private struct DotView: View {

    @Binding var transY: CGFloat

    let color: Color
    let height: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: height, height: height)
            .offset(y: transY)
    }
}

private struct AnimationData {
    var delay: TimeInterval
    var ty: CGFloat
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
