//
//  UserProfileView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import SwiftUI
import BaseStyle
import Data

struct UserProfileView: View {

    @StateObject var viewModel: UserProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    VSpacer(30)

                    UserProfileImageView(image: $viewModel.profileImage,
                                         profileImageUrl: viewModel.profileImageUrl,
                                         showOverlay: true,
                                         handleProfileTap: viewModel.handleProfileTap)
                    .confirmationDialog("", isPresented: $viewModel.showImagePickerOption, titleVisibility: .hidden) {
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

                    UserDetailList(firstName: $viewModel.firstName, lastName: $viewModel.lastName,
                                   email: $viewModel.email, phone: $viewModel.phone,
                                   userLoginType: $viewModel.userLoginType)

                    VSpacer(8)

                    Button(action: viewModel.showDeleteAccountConfirmation) {
                        HStack(spacing: 10) {
                            if viewModel.isDeleteInProgress {
                                LoaderView(tintColor: primaryColor, scaleSize: 1)
                                    .frame(width: 20)
                            }

                            Text("Delete account")
                                .font(.buttonText())
                                .foregroundStyle(awarenessColor)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(containerLowColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.scale)
                    .hidden(viewModel.isOpenedFromOnboard)

                    VSpacer(40)
                }
                .disabled(viewModel.isDeleteInProgress || viewModel.isSaveInProgress)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .background(surfaceColor)
        .navigationBarTitle("Profile", displayMode: .inline)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing, content: {
                if viewModel.isSaveInProgress {
                    LoaderView(tintColor: primaryColor, scaleSize: 1)
                        .frame(height: 50)
                        .padding(.trailing, 5)
                } else {
                    Button(action: viewModel.updateUserProfile) {
                        Image((viewModel.email.isValidEmail && viewModel.firstName.trimming(spaces: .leadingAndTrailing).count >= 3) ? .savePrimaryIcon : .saveIcon)
                            .resizable()
                            .frame(width: 26, height: 26)
                    }
                    .disabled(!viewModel.email.isValidEmail || viewModel.firstName.trimming(spaces: .leadingAndTrailing).count < 3)
                    .opacity((viewModel.email.isValidEmail && viewModel.firstName.trimming(spaces: .leadingAndTrailing).count >= 3) ? 1 : 0.6)
                }
            })
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square, sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.profileImage, isPresented: $viewModel.showImagePicker)
        }
    }
}

private struct UserDetailList: View {

    @FocusState var focusedField: UserProfileList?

    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var phone: String
    @Binding var userLoginType: LoginType

    var titles: [Binding<String>] {
        [$firstName, $lastName, $email, $phone]
    }

    var profileOptions: [UserProfileList] {
        UserProfileList.allCases
    }

    var isEmailDisable: Bool {
        (userLoginType == .Google || userLoginType == .Apple) && !email.isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            ForEach(profileOptions.indices, id: \.self) { index in
                UserDetailCell(titleText: titles[index], focused: $focusedField,
                               isDisabled: userLoginType == .Phone ? profileOptions[index].isDisabled : (profileOptions[index] == .email ? isEmailDisable : false),
                               placeholder: profileOptions[index].placeholder,
                               subtitleText: profileOptions[index].subtitle,
                               validationEnabled: profileOptions[index].validationType == .email || profileOptions[index].validationType == .phone || profileOptions[index].validationType == .firstName,
                               fieldType: profileOptions[index].fieldTypes,
                               keyboardType: profileOptions[index].keyboardType,
                               validationType: profileOptions[index].validationType,
                               autoCapitalizationType: profileOptions[index].autoCapitalizationType)
            }
        }
    }
}

private struct UserDetailCell: View {

    @State var isValidInput: Bool = true

    @Binding var titleText: String

    var focused: FocusState<UserProfileList?>.Binding

    let isDisabled: Bool
    let placeholder: String
    let subtitleText: String
    let validationEnabled: Bool
    let fieldType: UserProfileList
    let keyboardType: UIKeyboardType
    let validationType: TextFieldValidationType
    var autoCapitalizationType: UITextAutocapitalizationType

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(subtitleText)
                .font(.body2())
                .lineSpacing(1)
                .foregroundStyle(disableText)
                .fixedSize()

            VSpacer(8)

            UserProfileDataEditableTextField(titleText: $titleText, isDisabled: isDisabled, placeholder: placeholder, fieldType: fieldType, keyboardType: keyboardType, focused: focused, autoCapitalizationType: autoCapitalizationType)

            VSpacer(8)

            VStack(spacing: 0) {
                if validationEnabled && !isValidInput && focused.wrappedValue == fieldType {
                    Divider()
                        .frame(height: 1)
                        .background(awarenessColor)
                    Text(validationType.errorText)
                        .font(.body1(12))
                        .foregroundStyle(awarenessColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Divider()
                        .frame(height: 1)
                        .background(focused.wrappedValue == fieldType ? primaryColor : outlineColor)
                }
            }
            .animation(.easeInOut, value: validationEnabled && !isValidInput)
        }
        .onChange(of: titleText) { newValue in
            if validationEnabled {
                switch validationType {
                case .firstName:
                    isValidInput = newValue.trimming(spaces: .leadingAndTrailing).count >= 3
                case .phone:
                    isValidInput = newValue.count > 4 && newValue.count < 20
                case .email:
                    isValidInput = newValue.isValidEmail
                case .nonEmpty:
                    isValidInput = !newValue.isEmpty
                case .none:
                    isValidInput = true
                }
            }
        }
    }
}

private struct UserProfileDataEditableTextField: View {

    @Binding var titleText: String

    let isDisabled: Bool
    let placeholder: String
    let fieldType: UserProfileList
    let keyboardType: UIKeyboardType
    var focused: FocusState<UserProfileList?>.Binding
    var autoCapitalizationType: UITextAutocapitalizationType

    var body: some View {
        TextField(placeholder.localized, text: $titleText)
            .font(.subTitle1())
            .focused(focused, equals: fieldType)
            .foregroundStyle(primaryText)
            .disableAutocorrection(true)
            .disabled(isDisabled)
            .keyboardType(keyboardType)
            .autocapitalization(autoCapitalizationType)
            .submitLabel(.next)
            .onSubmit {
                if focused.wrappedValue == .firstName {
                    focused.wrappedValue = .lastName
                } else if focused.wrappedValue == .lastName {
                    focused.wrappedValue = .email
                } else if focused.wrappedValue == .email {
                    focused.wrappedValue = .firstName
                }
            }
    }
}

#Preview {
    UserProfileView(viewModel: UserProfileViewModel(router: .init(root: .ProfileView), isOpenedFromOnboard: true, onDismiss: nil))
}
