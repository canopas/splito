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
                    DecoratedProfileImageView(profileImage: $viewModel.profileImage,
                                              showImagePickerOption: $viewModel.showImagePickerOption,
                                              profileImageUrl: viewModel.profileImageUrl,
                                              handleProfileTap: viewModel.handleProfileTap,
                                              handleActionSelection: viewModel.handleActionSelection(_:))

                    UserDetailList(firstName: $viewModel.firstName, lastName: $viewModel.lastName,
                                   email: $viewModel.email, phone: $viewModel.phoneNumber,
                                   userLoginType: $viewModel.userLoginType)

                    if viewModel.isOpenFromOnboard {
                        let isEnable = (viewModel.email.isValidEmail &&
                                        viewModel.firstName.trimming(spaces: .leadingAndTrailing).count >= 3) ||
                        !(viewModel.userLoginType == .Google)

                        PrimaryButton(text: "Save", isEnabled: isEnable,
                                      showLoader: viewModel.isSaveInProgress, onClick: viewModel.updateUsersProfileData)
                    }

                    PrimaryButton(text: "Delete Account", textColor: alertColor,
                                  bgColor: container2Color, showLoader: viewModel.isDeleteInProgress,
                                  onClick: viewModel.showDeleteAccountConfirmation)
                    .hidden(viewModel.isOpenFromOnboard)
                    .padding(.bottom, 20)
                }
                .disabled(viewModel.isDeleteInProgress || viewModel.isSaveInProgress)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("")
        .padding(.horizontal, 16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Profile")
            }
            ToolbarItem(placement: .topBarTrailing, content: {
                CheckmarkButton(showLoader: viewModel.isSaveInProgress, iconSize: (24, 32), padding: (.leading, 16), onClick: viewModel.updateUsersProfileData)
                    .disabled(!viewModel.email.isValidEmail || viewModel.firstName.trimming(spaces: .leadingAndTrailing).count < 3)
                    .opacity((viewModel.email.isValidEmail && viewModel.firstName.trimming(spaces: .leadingAndTrailing).count >= 3) ? 1 : 0.6)
            })
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square, sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.profileImage, isPresented: $viewModel.showImagePicker)
        }
        .sheet(isPresented: $viewModel.showOTPView) {
            VerifyOtpView(viewModel: VerifyOtpViewModel(phoneNumber: viewModel.phoneNumber,
                                                        verificationId: viewModel.verificationId,
                                                        onLoginSuccess: viewModel.otpPublisher.send(_:)))
        }
    }
}

private struct DecoratedProfileImageView: View {

    @Binding var profileImage: UIImage?
    @Binding var showImagePickerOption: Bool

    let profileImageUrl: String?

    let handleProfileTap: () -> Void
    let handleActionSelection: (UserProfileViewModel.ActionsOfSheet) -> Void

    var body: some View {
        VSpacer(16)

        ZStack {
            Circle()
                .fill(primaryDarkColor.opacity(0.02))
                .frame(width: 176, height: 176)

            Circle()
                .fill(primaryDarkColor.opacity(0.05))
                .frame(width: 128, height: 128)

            UserProfileImageView(image: $profileImage,
                                 profileImageUrl: profileImageUrl,
                                 size: (80, 80),
                                 showOverlay: true,
                                 handleProfileTap: handleProfileTap)
            .confirmationDialog("", isPresented: $showImagePickerOption, titleVisibility: .hidden) {
                Button("Take a picture") {
                    handleActionSelection(.camera)
                }
                Button("Choose from Library") {
                    handleActionSelection(.gallery)
                }
                if profileImage != nil || profileImageUrl != nil {
                    Button("Remove picture") {
                        handleActionSelection(.remove)
                    }
                }
            }
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
        [$firstName, $lastName, $phone, $email]
    }

    var profileOptions: [UserProfileList] {
        UserProfileList.allCases
    }

    var isEmailDisable: Bool {
        userLoginType == .Google
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
        .padding(.horizontal, 1)
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
    var autoCapitalizationType: TextInputAutocapitalization

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(subtitleText.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VSpacer(8)

            UserProfileDataEditableTextField(titleText: $titleText,
                                             showError: (validationEnabled && !isValidInput && focused.wrappedValue == fieldType),
                                             isDisabled: isDisabled, placeholder: placeholder, fieldType: fieldType,
                                             keyboardType: keyboardType, focused: focused, autoCapitalizationType: autoCapitalizationType)

            VSpacer(8)

            VStack(spacing: 0) {
                if validationEnabled && !isValidInput && focused.wrappedValue == fieldType {
                    Text(validationType.errorText.localized)
                        .font(.body1(12))
                        .foregroundStyle(alertColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    let showError: Bool
    let isDisabled: Bool
    let placeholder: String
    let fieldType: UserProfileList
    let keyboardType: UIKeyboardType
    var focused: FocusState<UserProfileList?>.Binding
    var autoCapitalizationType: TextInputAutocapitalization

    var body: some View {
        TextField(placeholder.localized, text: $titleText)
            .font(.subTitle2())
            .focused(focused, equals: fieldType)
            .foregroundStyle(primaryText)
            .tint(primaryColor)
            .autocorrectionDisabled()
            .disabled(isDisabled)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autoCapitalizationType)
            .submitLabel(.next)
            .onSubmit {
                if focused.wrappedValue == .firstName {
                    focused.wrappedValue = .lastName
                } else if focused.wrappedValue == .lastName {
                    focused.wrappedValue = .phone
                } else if focused.wrappedValue == .phone {
                    focused.wrappedValue = .email
                } else if focused.wrappedValue == .email {
                    focused.wrappedValue = .firstName
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? alertColor : outlineColor, lineWidth: 1)
            }
    }
}
