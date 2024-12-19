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

                        JoinMemberTextInputView(text: $viewModel.code, placeholder: "AF0R00", isFocused: $isFocused) {
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
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
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

public struct JoinMemberTextInputView: View {

    private let CODE_TOTAL_CHARACTERS = 6

    @Binding var text: String

    let placeholder: String
    let isFocused: FocusState<Bool>.Binding

    var onCodeChange: (() -> Void)

    public var body: some View {
        TextField(placeholder.localized, text: $text)
            .kerning(16)
            .focused(isFocused)
            .tint(primaryColor)
            .font(.Header2())
            .keyboardType(.alphabet)
            .foregroundStyle(primaryText)
            .multilineTextAlignment(.center)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .onChange(of: text) { newValue in
                // Restrict the length of text
                if newValue.count > CODE_TOTAL_CHARACTERS {
                    text = String(newValue.prefix(CODE_TOTAL_CHARACTERS))
                    return
                }

                // Validate input characters by allowing only alphanumeric
                text = newValue.filter { $0.isLetter || $0.isNumber }

                if newValue.count == CODE_TOTAL_CHARACTERS {
                    onCodeChange()
                    isFocused.wrappedValue = false
                }
            }
            .textInputAutocapitalization(.characters)
            .onAppear {
                isFocused.wrappedValue = true
            }
    }
}
