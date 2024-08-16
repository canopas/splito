//
//  InviteMemberView.swift
//  Splito
//
//  Created by Amisha Italiya on 11/03/24.
//

import SwiftUI
import BaseStyle

struct InviteMemberView: View {

    @StateObject var viewModel: InviteMemberViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                ScrollView {
                    VStack(alignment: .center, spacing: 40) {
                        VStack(spacing: 16) {
                            Text("Share this code to invite friends.")
                                .font(.Header1())
                                .foregroundStyle(primaryText)
                                .multilineTextAlignment(.center)

                            Text("Let's get the gang together! Invite your friends to join the group and make splitting expenses easier than ever.")
                                .font(.subTitle1())
                                .foregroundStyle(disableText)
                                .tracking(-0.2)
                                .lineSpacing(4)
                        }
                        .multilineTextAlignment(.center)

                        VStack(spacing: 16) {
                            Text(viewModel.inviteCode)
                                .font(.Header2())
                                .foregroundStyle(primaryDarkColor)

                            Text("This code will be active for 2 days.")
                                .font(.body1())
                                .foregroundStyle(disableText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 40)
                        .background(containerColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: geometry.size.height - 90)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryFloatingButton(text: "Invite", onClick: viewModel.openShareSheet)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheetView(activityItems: ["Let's split the expense! Use invite code \(viewModel.inviteCode) to join the \(viewModel.group?.name ?? "") group, if you don't have an app then please download it."]) { isCompleted in
                if isCompleted {
                    viewModel.storeSharedCode {
                        dismiss()
                    }
                }
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Invite Code")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

#Preview {
    InviteMemberView(viewModel: InviteMemberViewModel(router: .init(root: .AccountHomeView), groupId: ""))
}
