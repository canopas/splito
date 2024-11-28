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
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: CreateGroupViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    VSpacer(40)

                    AddGroupImageView(showImagePickerOptions: $viewModel.showImagePickerOptions, image: viewModel.profileImage,
                                      imageUrl: viewModel.profileImageUrl, handleProfileTap: viewModel.handleProfileTap,
                                      handleActionSelection: viewModel.handleActionSelection(_:))

                    VSpacer(30)

                    AddGroupNameView(groupName: $viewModel.groupName)
                        .focused($isFocused)

                    Spacer(minLength: 130)
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            PrimaryButton(text: viewModel.group != nil ? "Save" : "Create", isEnabled: viewModel.groupName.count >= 3, showLoader: viewModel.showLoader, onClick: {
                Task {
                    let isSucceed = await viewModel.handleDoneAction()
                    if isSucceed {
                        dismiss()
                    } else {
                        viewModel.showSaveFailedToast()
                    }
                }
            })
            .padding(.bottom, 20)
            .padding(.horizontal, 16)
        }
        .onAppear {
            isFocused = true
        }
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .onTapGesture {
            isFocused = false
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: viewModel.group == nil ? "Create a group" : "Edit group")
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square, sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.profileImage, isPresented: $viewModel.showImagePicker)
        }
    }
}

private struct AddGroupImageView: View {

    @Binding var showImagePickerOptions: Bool

    let image: UIImage?
    let imageUrl: String?

    let handleProfileTap: (() -> Void)
    let handleActionSelection: ((ActionsOfSheet) -> Void)

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder({ _ in
                        ImageLoaderView()
                    })
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(.group)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 80, height: 80)
        .background(container2Color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            Image(.editPencilIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18, alignment: .center)
                .padding(4)
                .background(containerColor)
                .clipShape(Circle())
                .padding([.top, .leading], 67)
        }
        .padding(.horizontal, 16)
        .onTapGesture(perform: handleProfileTap)
        .confirmationDialog("", isPresented: $showImagePickerOptions, titleVisibility: .hidden) {
            ImagePickerOptionsView(image: image, imageUrl: imageUrl, handleActionSelection: handleActionSelection)
        }
    }
}

struct ImagePickerOptionsView: View {

    let image: UIImage?
    let imageUrl: String?

    let handleActionSelection: (ActionsOfSheet) -> Void

    var body: some View {
        Button("Take a picture") {
            handleActionSelection(.camera)
        }
        Button("Choose from Library") {
            handleActionSelection(.gallery)
        }
        if image != nil || (imageUrl != nil && !(imageUrl?.isEmpty ?? false)) {
            Button("Remove", role: .destructive) {
                handleActionSelection(.remove)
            }
        }
    }
}

private struct AddGroupNameView: View {

    @Binding var groupName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Group Name")
                .font(.body3())
                .foregroundStyle(disableText)

            TextField("", text: $groupName)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .tint(primaryColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }
                .autocorrectionDisabled()
        }
    }
}
