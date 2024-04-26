//
//  JoinMemberView.swift
//  Splito
//
//  Created by Amisha Italiya on 13/03/24.
//

import SwiftUI
import BaseStyle

struct JoinMemberView: View {

    @ObservedObject var viewModel: JoinMemberViewModel

    @State var selectedField: Int = 0

    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                VSpacer(30)

                HeaderTextView(title: "Enter the Invite Code", alignment: .center)

                JoinWithCodeView(code: $viewModel.code, selectedField: $selectedField)

                SubtitleTextView(text: "Get the code from the group creator to join.")

                PrimaryButton(text: "Join Group") {
                    viewModel.joinMemberWithCode()
                }

                Spacer()
            }
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

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            CustomTextField(text: $code, selectedField: $selectedField, placeholder: "Code",
                            font: .inter(.medium, size: 34), placeholderFont: .inter(.medium, size: 16),
                            tag: 1, keyboardType: .alphabet, returnKey: .done, textAlignment: .center,
                            characterLimit: 6, textContentType: .oneTimeCode)
            .frame(height: 45, alignment: .center)
            .background(Color.clear)

            Divider()
                .background(outlineColor)
                .padding(.horizontal, 60)
        }
        .onAppear {
            if code.isEmpty {
                selectedField = 1
            } else {
                selectedField = 0
                UIApplication.shared.endEditing()
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: code) { _ in
            if code.count == CODE_TOTAL_CHARACTERS {
                UIApplication.shared.endEditing()
            }
        }
    }
}

#Preview {
    JoinMemberView(viewModel: JoinMemberViewModel(router: .init(root: .JoinMemberView)))
}
