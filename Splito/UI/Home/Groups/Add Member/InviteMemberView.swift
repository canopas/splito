//
//  InviteMemberView.swift
//  Splito
//
//  Created by Amisha Italiya on 11/03/24.
//

import SwiftUI
import BaseStyle

struct InviteMemberView: View {

    @ObservedObject var viewModel: InviteMemberViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 40) {
            VSpacer(30)

            VStack(alignment: .leading, spacing: 10) {
                Text("Invite members to the group")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.leading)

                Text("Share this invitation code with your trusted one in your own style. Connecting with your friends is as flexible as you are.")
                    .font(.subTitle1())
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.leading)
            }

            VStack(spacing: 10) {
                Text(viewModel.inviteCode)
                    .font(.H1Text())
                    .foregroundStyle(primaryColor)

                Text("This code will be active for 2 days.")
                    .font(.subTitle2())
                    .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(primaryColor.opacity(0.12))
            .cornerRadius(20)

            PrimaryButton(text: "Share Code") {
                viewModel.showShareSheet = true
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(backgroundColor)
        .setNavigationTitle("Invite Code")
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheetView(activityItems: ["Let's split the expense! Use invite code \(viewModel.inviteCode) to join the \(viewModel.group?.name ?? "") group, don't have an app then please download it."]) { isCompleted in
                if isCompleted {
                    viewModel.storeSharedCode()
                }
            }
        }
    }
}

#Preview {
    InviteMemberView(viewModel: InviteMemberViewModel(router: .init(initial: .AccountHomeView), groupId: ""))
}
