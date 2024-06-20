//
//  JoinMemberView.swift
//  Splito
//
//  Created by Amisha Italiya on 13/03/24.
//

import SwiftUI
import BaseStyle

struct JoinMemberView: View {

    @StateObject var viewModel: JoinMemberViewModel

    @State var selectedField: Int = 0

    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            VSpacer(40)

            HeaderTextView(title: "Enter the Invite Code", alignment: .center)

            JoinWithCodeView(code: $viewModel.code, selectedField: $selectedField)

            SubtitleTextView(text: "Get the code from the group creator to join.")

            PrimaryButton(text: "Join Group", isEnabled: !viewModel.code.isEmpty, showLoader: viewModel.showLoader, onClick: viewModel.joinMemberWithCode)

            Spacer()
        }
        .padding(.horizontal, 22)
        .background(backgroundColor)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Join Group", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct JoinWithCodeView: View {

    @Binding var code: String
    @Binding var selectedField: Int

    private let CODE_TOTAL_CHARACTERS = 6
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            TextField("Code", text: $code)
                .font(.subTitle1(34))
                .foregroundColor(primaryText)
                .kerning(16)
                .multilineTextAlignment(.center)
                .keyboardType(.alphabet)
                .textContentType(.oneTimeCode)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: code) { newValue in
                    if newValue.count > CODE_TOTAL_CHARACTERS {
                        code = String(newValue.prefix(CODE_TOTAL_CHARACTERS))
                    }
                    if newValue.count == CODE_TOTAL_CHARACTERS {
                        UIApplication.shared.endEditing()
                    }
                }

            Divider()
                .background(outlineColor)
                .padding(.horizontal, 60)
        }
        .onAppear {
            if code.isEmpty {
                isFocused = true
            } else {
                isFocused = false
                UIApplication.shared.endEditing()
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: selectedField) { newValue in
            isFocused = (newValue == 1)
        }
    }
}

#Preview {
    JoinMemberView(viewModel: JoinMemberViewModel(router: .init(root: .JoinMemberView)))
}
