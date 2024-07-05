//
//  GroupSettleUpView.swift
//  Splito
//
//  Created by Amisha Italiya on 03/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupSettleUpView: View {

    @StateObject var viewModel: GroupSettleUpViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VSpacer(10)

                        Text("Which balance do you want to settle?")
                            .font(.body1(24))
                            .foregroundStyle(primaryText)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                        GroupMembersListView(viewModel: viewModel)

                        GroupSettleUpMoreOptionView(onMoreBtnTap: viewModel.handleMoreButtonTap)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .interactiveDismissDisabled()
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Settle up", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

private struct GroupSettleUpMoreOptionView: View {

    let onMoreBtnTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("More options")
                .font(.body1())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 20)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.4))
        }
        .onTouchGesture {
            onMoreBtnTap()
        }
    }
}

private struct GroupMembersListView: View {

    @ObservedObject var viewModel: GroupSettleUpViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let sortedMembers = viewModel.memberOwingAmount
                .sorted { (member1, member2) -> Bool in
                    guard let member1Data = viewModel.getMemberDataBy(id: member1.key),
                          let member2Data = viewModel.getMemberDataBy(id: member2.key) else {
                        return false
                    }

                    let name1 = member1Data.fullName.lowercased()
                    let name2 = member2Data.fullName.lowercased()

                    return name1 < name2
                }

            ForEach(sortedMembers, id: \.key) { memberId, owingAmount in
                if let member = viewModel.getMemberDataBy(id: memberId) {
                    GroupMemberCellView(member: member, amount: owingAmount)
                        .onTouchGesture {
                            viewModel.onMemberTap(memberId: member.id, amount: owingAmount)
                        }

                    Divider()
                        .frame(height: 1)
                        .background(outlineColor.opacity(0.4))
                }
            }
        }
    }
}

private struct GroupMemberCellView: View {

    let member: AppUser
    let amount: Double

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
                Text(member.fullName)
                    .lineLimit(1)
                    .font(.body1())
                    .foregroundStyle(primaryText)

                Text(subInfo)
                    .lineLimit(1)
                    .font(.subTitle3())
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            let isBorrowed = amount < 0
            VStack(alignment: .trailing, spacing: 4) {
                Text(isBorrowed ? "you owe" : "owes you")
                    .font(.body1(13))

                Text(amount.formattedCurrency)
                    .font(.body1())
            }
            .lineLimit(1)
            .foregroundStyle(isBorrowed ? amountBorrowedColor : amountLentColor)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    GroupSettleUpView(viewModel: GroupSettleUpViewModel(router: nil, groupId: ""))
}
