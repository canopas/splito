//
//  ChooseGroupView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct ChooseGroupView: View {

    @StateObject var viewModel: ChooseGroupViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.4))

            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .noGroups = viewModel.currentViewState {
                NoGroupFoundView()
            } else if case .hasGroups(let groups) = viewModel.currentViewState {
                ScrollView {
                    VSpacer(40)

                    LazyVStack(spacing: 16) {
                        ForEach(groups) { group in
                            GroupCellView(group: group, isSelected: group.id == viewModel.selectedGroup?.id)
                                .onTapGesture {
                                    viewModel.handleGroupSelection(group: group)
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
        .navigationBarTitle("Choose Group", displayMode: .inline)
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

private struct NoGroupFoundView: View {

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("You are not part of any group.")
                .font(.Header1(22))
                .foregroundStyle(primaryColor)
                .multilineTextAlignment(.center)

            Text("Groups help you stay organized by tracking and splitting expenses for various activities.")
                .font(.subTitle3(15))
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

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            GroupProfileImageView(imageUrl: group.imageUrl)

            Text(group.name)
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
    ChooseGroupView(viewModel: ChooseGroupViewModel(selectedGroup: nil, onGroupSelection: { _ in }))
}
