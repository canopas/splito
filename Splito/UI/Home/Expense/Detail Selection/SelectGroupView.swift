//
//  SelectGroupView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct SelectGroupView: View {

    @StateObject var viewModel: SelectGroupViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarTopView(title: "Select a group", leadingButton: EmptyView(),
                trailingButton: DismissButton(padding: (16, 0), foregroundColor: primaryText, onDismissAction: {
                    dismiss()
                })
                .fontWeight(.regular)
            )
            .padding(.leading, 16)

            Spacer(minLength: 0)

            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .noGroups = viewModel.currentViewState {
                NoGroupFoundView()
            } else if case .hasGroups(let groups) = viewModel.currentViewState {
                ScrollView {
                    VSpacer(36)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { group in
                            GroupCellView(group: group, isSelected: group.id == viewModel.selectedGroup?.id, action: {
                                viewModel.handleGroupSelection(group: group)
                            })
                            .onTapGestureForced {
                                viewModel.handleGroupSelection(group: group)
                            }
                        }
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryButton(text: "Done", isEnabled: viewModel.selectedGroup != nil, onClick: {
                    viewModel.handleDoneAction {
                        dismiss()
                    }
                })
                .padding([.bottom, .horizontal], 16)
                .padding(.top, 8)
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct NoGroupFoundView: View {

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("You are not part of any group.")
                .font(.Header2())
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text("Groups help you stay organized by tracking and splitting expenses for various activities.")
                .font(.subTitle3())
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(5)

            Spacer()
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupCellView: View {

    var group: Groups
    var isSelected: Bool

    var action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            GroupProfileImageView(imageUrl: group.imageUrl, size: (32, 32))

            Text(group.name)
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Spacer()

            RadioButton(isSelected: isSelected, action: action)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)

        Divider()
            .frame(height: 1)
            .background(dividerColor)
            .padding(.vertical, 20)
    }
}

#Preview {
    SelectGroupView(viewModel: SelectGroupViewModel(selectedGroup: nil, onGroupSelection: { _ in }))
}
