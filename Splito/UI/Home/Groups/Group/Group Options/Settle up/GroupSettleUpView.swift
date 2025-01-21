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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialViewData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VSpacer(27)

                        GroupMembersListView(viewModel: viewModel)

                        GroupSettleUpMoreOptionView(onMoreBtnTap: viewModel.handleMoreButtonTap)
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Settle up")
            }
        }
    }
}

private struct GroupSettleUpMoreOptionView: View {

    let onMoreBtnTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("More options")
                .font(.Header4())
                .foregroundStyle(primaryText)

            Spacer()

            ScrollToTopButton(icon: "chevron.right", iconColor: primaryText, bgColor: .clear, size: (7, 14), padding: 3, onClick: onMoreBtnTap)
                .fontWeight(.regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .onTapGestureForced(perform: onMoreBtnTap)
    }
}

private struct GroupMembersListView: View {

    @ObservedObject var viewModel: GroupSettleUpViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let sortedMembers = viewModel.memberOwingAmount
                .sorted { (entry1, entry2) -> Bool in
                    guard let member1Data = viewModel.getMemberDataBy(id: entry1.memberId),
                          let member2Data = viewModel.getMemberDataBy(id: entry2.memberId) else {
                        return false
                    }

                    let name1 = member1Data.fullName.lowercased()
                    let name2 = member2Data.fullName.lowercased()

                    return name1 < name2
                }

            ForEach(sortedMembers, id: \.id) { memberBalance in
                if let member = viewModel.getMemberDataBy(id: memberBalance.memberId) {
                    GroupMemberCellView(member: member, memberBalance: memberBalance)
                        .onTouchGesture {
                            viewModel.onMemberTap(memberBalance: memberBalance)
                        }

                    Divider()
                        .frame(height: 1)
                        .background(dividerColor)
                }
            }
        }
    }
}

private struct GroupMemberCellView: View {

    let member: AppUser
    let memberBalance: CombineMemberOwingAmount

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            Text(member.fullName)
                .lineLimit(1)
                .font(.subTitle1())
                .foregroundStyle(primaryText)

            Spacer()

            let isBorrowed = memberBalance.balance < 0
            VStack(alignment: .trailing, spacing: 4) {
                Text(isBorrowed ? "you owe" : "owes you")
                    .font(.caption1())

                Text(abs(memberBalance.balance).formattedCurrencyWithSign(memberBalance.currencyCode))
                    .font(.body1())
            }
            .lineLimit(1)
            .foregroundStyle(isBorrowed ? errorColor : successColor)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }
}
