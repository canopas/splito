//
//  BottomSheetView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 10/07/24.
//

import SwiftUI

public struct BottomSheetView<Content>: View where Content: View {

    public let content: () -> Content
    public let onDismiss: () -> Void
    @State var isAnimating: Bool = false

    public init(content: @escaping () -> Content, onDismiss: @escaping () -> Void) {
        self.content = content
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            BottomSheetContentView(isAnimating: $isAnimating, content: {
                VStack(spacing: 0) {
                    content()
                }
            }, onDismiss: {
                performDisappearAnimation {
                    onDismiss()
                }
            })
        }
    }

    public func performDisappearAnimation(completion: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            completion?()
        })
    }
}

public struct BottomSheetContentView<Content>: View where Content: View {

    @Binding var isAnimating: Bool

    private let content: () -> Content
    private var onDismiss: (() -> Void)?

    public init(isAnimating: Binding<Bool>, content: @escaping () -> Content, onDismiss: (() -> Void)? = nil) {
        self._isAnimating = isAnimating
        self.content = content
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                VSpacer()
            }
            .frame(maxWidth: .infinity)
            .background(content: {
                isAnimating ? (ZStack { bottomSheetBgColor }.ignoresSafeArea()) : nil
            })
            .onTapGesture {
                performDismissAction()
            }
            .gesture(DragGesture().onEnded { _ in
                performDismissAction()
            })
            .overlay(alignment: .bottom, content: {
                VStack(spacing: 0, content: {
                    content()
                })
                .background(backgroundColor)
                .cornerRadius(16, corners: [.topLeft, .topRight])
            })
            .edgesIgnoringSafeArea(.bottom)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isAnimating = true
                }
            }
        }
    }

    private func performDismissAction() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnimating = false
        }
        onDismiss?()
    }
}
