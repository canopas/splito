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

    @ObservedObject var viewModel: ChooseGroupViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else if case .noGroups = viewModel.currentViewState {
                NoGroupFoundView()
            } else if case .hasGroups(let groups) = viewModel.currentViewState {
                VSpacer(10)

                Text("Choose Group")
                    .font(.Header3())
                    .foregroundStyle(.primary)

                VSpacer(10)

                ScrollView(showsIndicators: false) {
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
            }
        }
        .padding(.horizontal, 30)
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct NoGroupFoundView: View {

    var body: some View {
        VStack {
            Text("You are not part of any group.")
                .font(.subTitle1())
                .foregroundStyle(primaryColor)
        }
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
        .background(backgroundColor)
    }
}

#Preview {
    ChooseGroupView(viewModel: ChooseGroupViewModel(selectedGroup: nil, onGroupSelection: { _ in }))
}
