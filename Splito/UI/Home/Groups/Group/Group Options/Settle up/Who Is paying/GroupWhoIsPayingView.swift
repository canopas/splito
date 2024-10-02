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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if .noInternet == viewModel.currentViewState || .somethingWentWrong == viewModel.currentViewState {
                ErrorView(isForNoInternet: viewModel.currentViewState == .noInternet, onClick: viewModel.fetchInitialMembersData)
            } else if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VSpacer(27)

                        ForEach(viewModel.members) { member in
                            GroupPayingMemberView(member: member, isSelected: member.id == viewModel.selectedMemberId,
                                                  isLastMember: member.id == viewModel.members.last?.id,
                                                  onMemberTap: viewModel.onMemberTap(_:))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onAppear(perform: viewModel.fetchInitialMembersData)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleView(navigationTitle: "Who is paying?")
            }
        }
    }
}

struct GroupPayingMemberView: View {

    let member: AppUser

    let isSelected: Bool
    let isLastMember: Bool
    let disableMemberTap: Bool

    let onMemberTap: (String) -> Void

    init(member: AppUser, isSelected: Bool = false, isLastMember: Bool, disableMemberTap: Bool = false, onMemberTap: @escaping (String) -> Void) {
        self.member = member
        self.isSelected = isSelected
        self.isLastMember = isLastMember
        self.disableMemberTap = disableMemberTap
        self.onMemberTap = onMemberTap
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            Text(member.fullName.localized)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .lineLimit(1)

            Spacer()

            if !disableMemberTap {
                RadioButton(isSelected: isSelected, action: {
                    onMemberTap(member.id)
                })
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 16)
        .opacity(disableMemberTap ? 0.4 : 1)
        .onTouchGesture {
            if !disableMemberTap {
                onMemberTap(member.id)
            }
        }

        if !isLastMember {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}
