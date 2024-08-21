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

    @StateObject var viewModel: CreateGroupViewModel

    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        VSpacer(40)

                        AddGroupImageView(image: viewModel.profileImage, imageUrl: viewModel.profileImageUrl, handleProfileTap: viewModel.handleProfileTap)

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
                    viewModel.handleDoneAction {
                        dismiss()
                    }
                })
                .padding(.bottom, 20)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            isFocused = true
        }
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
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
        .onTapGesture {
            isFocused = false
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(viewModel.group == nil ? "Create a group" : "Edit group")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

private struct AddGroupImageView: View {

    let image: UIImage?
    let imageUrl: String?

    let handleProfileTap: (() -> Void)

    var body: some View {
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
        }
    }
}

#Preview {
    CreateGroupView(viewModel: CreateGroupViewModel(router: .init(root: .CreateGroupView(group: nil))))
}
