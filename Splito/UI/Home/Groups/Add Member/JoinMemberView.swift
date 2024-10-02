//
//  JoinMemberView.swift
//  Splito
//
//  Created by Amisha Italiya on 13/03/24.
//

import SwiftUI
import BaseStyle

struct JoinMemberView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: JoinMemberViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                ScrollView {
                    VStack(spacing: 36) {
                        Spacer()

                        Text("Enter the invite code")
                            .font(.Header1())
                            .foregroundStyle(primaryText)
                            .multilineTextAlignment(.center)

                        OtpTextInputView(text: $viewModel.code, placeholder: "AF0R00", isFocused: $isFocused,
                                         keyboardType: .alphabet) {
                            viewModel.handleJoinMemberAction { isSucceed in
                                if isSucceed { dismiss() }
                            }
                        }

                        Text("Reach out to your friends to get the code of the group they created.")
                            .font(.subTitle1())
                            .foregroundStyle(disableText)
                            .tracking(-0.2)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: geometry.size.height - 90)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryFloatingButton(text: "Join", isEnabled: !viewModel.code.isEmpty, showLoader: viewModel.showLoader) {
                    viewModel.handleJoinMemberAction { isSucceed in
                        if isSucceed { dismiss() }
                    }
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            isFocused = false
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Join Group")
            }
        }
    }
}
