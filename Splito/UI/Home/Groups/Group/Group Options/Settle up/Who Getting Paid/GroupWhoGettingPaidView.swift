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
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.members) { member in
                            GroupPayingMemberView(member: member, selectedMemberId: viewModel.selectedMemberId)
                                .onTouchGesture {
                                    viewModel.onMemberTap(memberId: member.id)
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
        .navigationBarTitle("Who is getting paid?", displayMode: .inline)
        .onAppear {
            viewModel.fetchGroupMembers()
        }
    }
}

#Preview {
    GroupWhoGettingPaidView(viewModel: GroupWhoGettingPaidViewModel(router: nil, groupId: "", selectedMemberId: ""))
}
