//
//  GroupWhoGettingPaidView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle

struct GroupWhoGettingPaidView: View {

    @StateObject var viewModel: GroupWhoGettingPaidViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchGroupWithMembersData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VSpacer(27)

                        ForEach(viewModel.members) { member in
                            GroupPayingMemberView(member: member, isSelected: member.id == viewModel.selectedMemberId,
                                                  isLastMember: member.id == viewModel.members.last?.id,
                                                  disableMemberTap: member.id == viewModel.payerId,
                                                  onMemberTap: viewModel.onMemberTap(memberId:))
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
        .onAppear(perform: viewModel.fetchGroupWithMembersData)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Who is getting paid?")
            }
        }
    }
}
