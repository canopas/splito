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
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else if case .success(let groups) = viewModel.currentViewState {
                ScrollView(showsIndicators: false) {
                    VSpacer(30)

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
        .navigationBarTitle("Choose group", displayMode: .inline)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
            }
        }
    }
}

struct GroupCellView: View {

    var group: Groups
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let imageUrl = group.imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder({ _ in
                        ImageLoaderView()
                    })
                    .setProcessor(ResizingImageProcessor(referenceSize: CGSize(width: (50 * UIScreen.main.scale), height: (50 * UIScreen.main.scale)), mode: .aspectFill))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(.group)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(group.name)
                .font(.subTitle2())
                .foregroundColor(primaryText)

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
