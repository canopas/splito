//
//  ChoosePayerView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct ChoosePayerView: View {

    @ObservedObject var viewModel: ChoosePayerViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.4))

            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .noMember = viewModel.currentViewState {
                NoMemberFoundView()
            } else if case .hasMembers(let users) = viewModel.currentViewState {
                ScrollView {
                    VSpacer(40)

                    LazyVStack(spacing: 16) {
                        ForEach(users) { user in
                            ChooseMemberCellView(member: user, isSelected: user.id == viewModel.selectedPayer?.id)
                                .onTapGesture {
                                    viewModel.handlePayerSelection(user: user)
                                    dismiss()
                                }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .interactiveDismissDisabled()
        .setNavigationTitle("Choose Payer")
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

private struct NoMemberFoundView: View {

    var body: some View {
        VStack {
            Text("No members in your selected group.")
                .font(.subTitle1())
                .foregroundStyle(primaryColor)
        }
    }
}

private struct ChooseMemberCellView: View {

    @Inject var preference: SplitoPreference

    var member: AppUser
    var isSelected: Bool

    var userName: String?

    init(member: AppUser, isSelected: Bool) {
        self.member = member
        self.isSelected = isSelected
        if let user = preference.user, member.id == user.id {
            self.userName = "You"
        } else {
            self.userName = member.fullName
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            Text((userName ?? "").isEmpty ? "Unknown" : userName!)
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Spacer()

            if isSelected {
                Image(.checkMarkTick)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 30)
        .background(backgroundColor)
    }
}

#Preview {
    ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: "", selectedPayer: nil, onPayerSelection: { _ in }))
}
