//
//  ToastView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import SwiftUI

struct ToastView: View {

    var type: ToastStyle
    var title: String
    var message: String
    let bottomPadding: CGFloat

    var onCancelTapped: (() -> Void)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: type.iconName)
                    .foregroundStyle(type.themeColor)
                    .padding(.trailing, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.localized)
                        .font(.buttonText())
                        .foregroundStyle(primaryText)

                    Text(message.localized)
                        .font(.body1(12))
                        .foregroundStyle(secondaryText)
                }

                Spacer(minLength: 10)

                DismissButton(iconSize: (18, .regular), foregroundColor: primaryText, onDismissAction: onCancelTapped)
            }
            .padding()
        }
        .background(surfaceColor)
        .overlay(
            Rectangle()
                .fill(type.themeColor)
                .frame(width: 6)
                .clipped()
            , alignment: .leading
        )
        .frame(minWidth: 0, maxWidth: isIpad ? 600 : .infinity, alignment: .center)
        .cornerRadius(8)
        .shadow(color: primaryLightText.opacity(0.8), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.bottom, bottomPadding)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastPrompt?

    let bottomPadding: CGFloat

    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    mainToastView()
                        .offset(y: -30)
                }.animation(.spring(), value: toast)
            )
            .onChange(of: toast) { _ in
                showToast()
            }
    }

    @ViewBuilder func mainToastView() -> some View {
        if let toast {
            VStack(spacing: 0) {
                Spacer()
                ToastView(type: toast.type, title: toast.title,
                          message: toast.message, bottomPadding: bottomPadding,
                          onCancelTapped: {
                            dismissToast()
                          })
            }
            .transition(.move(edge: .bottom))
        }
    }

    private func showToast() {
        guard let toast = toast else { return }

        // This will generate feedback (Vibration) so user get attention like something happened
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if toast.duration > 0 {
            workItem?.cancel()

            let task = DispatchWorkItem {
                dismissToast()
            }

            workItem = task
            // This will delay the task for time now to deadline and do the task after deadline
            // basically it will dismiss toast after toast.duration which is default 3 sec
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
        }
    }

    private func dismissToast() {
        toast?.onDismiss?()
        withAnimation {
            toast = nil
        }

        workItem?.cancel()
        workItem = nil
    }
}

public extension View {
    func toastView(toast: Binding<ToastPrompt?>, bottomPadding: CGFloat = 0) -> some View {
        self.modifier(ToastModifier(toast: toast, bottomPadding: bottomPadding))
    }
}
