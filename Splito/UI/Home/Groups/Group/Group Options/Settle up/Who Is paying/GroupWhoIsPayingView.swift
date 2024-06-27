//
//  GroupWhoIsPayingView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupWhoIsPayingView: View {

    @StateObject var viewModel: GroupWhoIsPayingViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.members) { member in
                            GroupPayingMemberView(member: member)
                                .onTouchGesture {
                                    viewModel.onMemberTap(member)
                                }

                            Divider()
                                .frame(height: 1)
                                .background(outlineColor.opacity(0.4))
                        }
                    }
                    .padding(.top, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Who is paying?", displayMode: .inline)
        .onAppear(perform: viewModel.fetchGroupMembers)
        .toolbar {
            if viewModel.isPaymentSettled {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GroupPayingMemberView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    let selectedMemberId: String?

    init(member: AppUser, selectedMemberId: String? = nil) {
        self.member = member
        self.selectedMemberId = selectedMemberId
    }

    private var subInfo: String {
        if let phoneNumber = member.phoneNumber, !phoneNumber.isEmpty {
            return phoneNumber
        } else if let emailId = member.emailId, !emailId.isEmpty {
            return emailId
        } else {
            return "No email address"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 2) {
                    Text(member.fullName.localized)
                        .lineLimit(1)
                        .font(.body1())
                        .foregroundStyle(primaryText)
                }

                Text(subInfo.localized)
                    .lineLimit(1)
                    .font(.subTitle3())
                    .foregroundStyle(secondaryText)
            }
            .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .opacity(member.id == selectedMemberId ? 0.2 : 1)
    }
}

#Preview {
    GroupWhoIsPayingView(viewModel: GroupWhoIsPayingViewModel(groupId: "", isPaymentSettled: true))
}
