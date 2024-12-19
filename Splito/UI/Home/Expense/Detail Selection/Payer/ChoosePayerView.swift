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
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: ChoosePayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarTopView(title: "Choose payer", leadingButton: EmptyView(),
                trailingButton: DismissButton(padding: (16, 0), foregroundColor: primaryText, onDismissAction: {
                    dismiss()
                })
                .fontWeight(.regular)
            )
            .padding(.leading, 16)

            Spacer(minLength: 0)

            if .noInternet == viewModel.currentViewState || .somethingWentWrong == viewModel.currentViewState {
                ErrorView(isForNoInternet: viewModel.currentViewState == .noInternet, onClick: viewModel.fetchInitialViewData)
            } else if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .noMember = viewModel.currentViewState {
                NoMemberFoundView()
            } else if case .hasMembers(let users) = viewModel.currentViewState {
                ScrollView {
                    VSpacer(27)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(users) { user in
                            ChooseMemberCellView(
                                member: user,
                                isSelected: (viewModel.selectedPayers.count > 1) ? false : viewModel.selectedPayers.keys.contains(user.id)
                            )
                            .onTapGestureForced {
                                viewModel.handlePayerSelection(userId: user.id)
                            }
                        }

                        if users.count > 1 {
                            MultiplePeopleCellView(isMultiplePayerselected: viewModel.selectedPayers.count > 1,
                                                   handleMultiplePayerTap: viewModel.handleMultiplePayerTap)
                        }
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryButton(text: "Save", isEnabled: !viewModel.selectedPayers.isEmpty, onClick: {
                    viewModel.handleSaveBtnTap()
                    dismiss()
                })
                .padding([.bottom, .horizontal], 16)
                .padding(.top, 8)
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct NoMemberFoundView: View {

    var body: some View {
        VStack(spacing: 0) {
            VSpacer()

            Text("No members in your selected group.")
                .font(.Header4())
                .foregroundStyle(secondaryText)

            VSpacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct ChooseMemberCellView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    let isSelected: Bool

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
        HStack(spacing: 16) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            Text(((userName ?? "").isEmpty ? "Unknown" : userName?.localized) ?? "")
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Spacer()

            if isSelected {
                CheckmarkButton(iconSize: (24, 32), padding: (.all, 0))
            }
        }
        .padding(16)

        Divider()
            .frame(height: 1)
            .background(dividerColor)
    }
}

private struct MultiplePeopleCellView: View {

    let isMultiplePayerselected: Bool
    let handleMultiplePayerTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Multiple people")
                .font(.Header4())
                .foregroundStyle(primaryText)

            Spacer()

            if isMultiplePayerselected {
                CheckmarkButton(iconSize: (24, 32), padding: (.all, 0))
            }
        }
        .onTapGestureForced {
            handleMultiplePayerTap()
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
}
