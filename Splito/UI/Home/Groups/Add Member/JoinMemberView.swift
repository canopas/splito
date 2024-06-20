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
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            VSpacer(40)

            HeaderTextView(title: "Enter the Invite Code", alignment: .center)

            OtpTextInputView(text: $viewModel.code, isFocused: $isFocused, keyboardType: .alphabet, onOtpVerify: viewModel.joinMemberWithCode)

            SubtitleTextView(text: "Get the code from the group creator to join.")

            PrimaryButton(text: "Join Group", isEnabled: !viewModel.code.isEmpty,
                          showLoader: viewModel.showLoader, onClick: viewModel.joinMemberWithCode)

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

#Preview {
    JoinMemberView(viewModel: JoinMemberViewModel(router: .init(root: .JoinMemberView)))
}
