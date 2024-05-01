//
//  CreateGroupView.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import SwiftUI
import BaseStyle
import Kingfisher

struct CreateGroupView: View {

    @ObservedObject var viewModel: CreateGroupViewModel

    var body: some View {
        VStack {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                VStack {
                    VSpacer(40)

                    AddGroupNameView(image: viewModel.profileImage, imageUrl: viewModel.profileImageUrl,
                                     groupName: $viewModel.groupName, handleProfileTap: viewModel.handleProfileTap)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle(viewModel.group == nil ? "Create a group" : "Edit group", displayMode: .inline)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .confirmationDialog("", isPresented: $viewModel.showImagePickerOptions, titleVisibility: .hidden) {
            Button("Take Picture") {
                viewModel.handleActionSelection(.camera)
            }
            Button("Choose from Library") {
                viewModel.handleActionSelection(.gallery)
            }
            if viewModel.profileImage != nil || viewModel.profileImageUrl != nil {
                Button("Remove") {
                    viewModel.handleActionSelection(.remove)
                }
                .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square,
                            sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.profileImage, isPresented: $viewModel.showImagePicker)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleDoneAction()
                } label: {
                    Text("Done")
                }
                .font(.subTitle2())
                .tint(primaryColor)
                .disabled(viewModel.groupName.count < 3 || viewModel.currentState == .loading)
            }
        }
    }
}

private struct AddGroupNameView: View {

    var image: UIImage?
    var imageUrl: String?
    @Binding var groupName: String

    let handleProfileTap: (() -> Void)

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let imageUrl, let url = URL(string: imageUrl) {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(.group)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 60, height: 60)
            .background(secondaryText.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(secondaryText)
            .onTapGesture {
                handleProfileTap()
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Group name")
                    .font(.subTitle2())
                    .foregroundStyle(secondaryText)

                TextField("", text: $groupName)

                Divider()
                    .frame(height: 1)
                    .background(outlineColor)
            }
        }
    }
}

#Preview {
    CreateGroupView(viewModel: CreateGroupViewModel(router: .init(root: .CreateGroupView(group: nil))))
}
