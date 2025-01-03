//
//  FeedbackView.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import SwiftUI
import BaseStyle
import AVKit
import Data

struct FeedbackView: View {

    @ObservedObject var viewModel: FeedbackViewModel

    @FocusState private var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VSpacer(24)

                VStack(spacing: 24) {
                    FeedbackTitleView(titleText: $viewModel.title, focusField: $focusField,
                                      isSelected: focusField == .title, isValidTitle: viewModel.isValidTitle,
                                      shouldShowValidationMessage: viewModel.shouldShowValidationMessage)

                    FeedbackDescriptionView(titleText: $viewModel.description, focusField: $focusField,
                                            isSelected: focusField == .description)

                    FeedbackAddAttachmentView(
                        attachedMedia: $viewModel.selectedAttachments, uploadingAttachments: $viewModel.uploadingAttachments,
                        failedAttachments: $viewModel.failedAttachments, selectedAttachments: $viewModel.selectedAttachments,
                        showMediaPickerOption: $viewModel.showMediaPickerOption, handleAttachmentTap: viewModel.handleAttachmentTap,
                        onRemoveAttachmentTap: viewModel.onRemoveAttachment, onRetryButtonTap: viewModel.onRetryAttachment(_:),
                        handleActionSelection: viewModel.handleActionSelection(_:), focusField: _focusField
                    )

                    PrimaryButton(
                        text: "Submit", isEnabled: viewModel.uploadingAttachments.isEmpty,
                        showLoader: viewModel.showLoader, onClick: viewModel.onSubmitBtnTap
                    )
                }
                .padding([.horizontal, .bottom], 16)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .onAppear {
            focusField = .title
            UIScrollView.appearance().keyboardDismissMode = .interactive
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Contact support")
            }
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $viewModel.showMediaPicker) {
            MultiMediaSelectionPickerView(isPresented: $viewModel.showMediaPicker,
                                          onDismiss: viewModel.onMediaPickerSheetDismiss(attachments:))
        }
    }
}

private struct FeedbackTitleView: View {

    @Binding var titleText: String
    var focusField: FocusState<FeedbackViewModel.FocusedField?>.Binding

    let isSelected: Bool
    let isValidTitle: Bool
    let shouldShowValidationMessage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Title")
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VSpacer(10)

            TextField("", text: $titleText)
                .font(.subTitle1())
                .foregroundColor(primaryText)
                .focused(focusField, equals: .title)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .padding(8)
                .submitLabel(.next)
                .onSubmit {
                    if focusField.wrappedValue == .title {
                        focusField.wrappedValue = .description
                    } else if focusField.wrappedValue == .description {
                        focusField.wrappedValue = nil
                    }
                }
                .onTapGestureForced {
                    focusField.wrappedValue = .title
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(shouldShowValidationMessage && !isValidTitle ? errorColor :
                                    isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )

            VSpacer(3)

            Text(shouldShowValidationMessage ? (isValidTitle ? " " : "Minimum 3 characters are required") : " ")
                .foregroundColor(errorColor)
                .font(.body1(12))
                .foregroundColor(errorColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

private struct FeedbackDescriptionView: View {

    @Binding var titleText: String
    var focusField: FocusState<FeedbackViewModel.FocusedField?>.Binding

    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Description")
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $titleText)
                .frame(height: UIScreen.main.bounds.height/4, alignment: .center)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .focused(focusField, equals: .description)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(4)
                .onTapGestureForced {
                    focusField.wrappedValue = .description
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )
        }
    }
}

private struct FeedbackAddAttachmentView: View {

    @Binding var attachedMedia: [Attachment]
    @Binding var uploadingAttachments: [Attachment]
    @Binding var failedAttachments: [Attachment]
    @Binding var selectedAttachments: [Attachment]
    @Binding var showMediaPickerOption: Bool

    let handleAttachmentTap: () -> Void
    let onRemoveAttachmentTap: (Attachment) -> Void
    let onRetryButtonTap: (Attachment) -> Void
    let handleActionSelection: (ActionsOfSheet) -> Void

    @FocusState var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(attachedMedia, id: \.id) { attachment in
                FeedbackAttachmentCellView(
                    attachment: attachment,
                    isUploading: uploadingAttachments.contains(where: { $0.id == attachment.id }),
                    showRetryButton: failedAttachments.contains(where: { $0.id == attachment.id }),
                    onRetryButtonTap: {_ in
                        onRetryButtonTap(attachment)
                    },
                    onRemoveAttachmentTap: {_ in
                        onRemoveAttachmentTap(attachment)
                    }
                )
            }

            Button {
                focusField = nil
                handleAttachmentTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                    Text("Add attachment")
                        .font(.body1())
                }
                .foregroundColor(uploadingAttachments.isEmpty ? disableText : primaryText)
            }
            .buttonStyle(.scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Choose mode\nPlease choose your preferred mode to includes attachment with feedback",
                            isPresented: $showMediaPickerOption, titleVisibility: .visible) {
            MediaPickerOptionsView(withRemoveAllOption: $selectedAttachments.count >= 1,
                                   handleActionSelection: handleActionSelection)
        }
    }
}

private struct FeedbackAttachmentCellView: View {

    let attachment: Attachment
    let isUploading: Bool
    let showRetryButton: Bool

    let onRetryButtonTap: (Attachment) -> Void
    let onRemoveAttachmentTap: (Attachment) -> Void

    @FocusState private var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        HStack(spacing: 0) {
            AttachmentThumbnailView(attachment: attachment, isUploading: isUploading,
                                    showRetryButton: showRetryButton, onRetryButtonTap: onRetryButtonTap)

            Text(attachment.name)
                .font(.body1())
                .foregroundColor(secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            DismissButton(iconName: "multiply.circle.fill", iconSize: (20, .regular)) {
                focusField = nil
                onRemoveAttachmentTap(attachment)
            }
            .padding([.vertical, .leading])
            .background(.linearGradient(.init(colors: [surfaceColor, surfaceColor, surfaceColor, surfaceColor, surfaceColor.opacity(0)]), startPoint: .trailing, endPoint: .leading))
        }
    }
}

private struct AttachmentThumbnailView: View {

    let attachment: Attachment
    let isUploading: Bool
    let showRetryButton: Bool

    let onRetryButtonTap: (Attachment) -> Void

    var body: some View {
        ZStack {
            if let image = attachment.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let video = attachment.video {
                VideoPlayer(player: AVPlayer(url: video))
            }

            Rectangle()
                .frame(width: 50, height: 50, alignment: .leading)
                .foregroundColor(isUploading || showRetryButton ? lowestText : .clear)

            if attachment.video != nil && !isUploading {
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(primaryColor)
            }

            if isUploading {
                ImageLoaderView(tintColor: primaryText)
            }

            if showRetryButton {
                Button {
                    onRetryButtonTap(attachment)
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(primaryColor)
                }
            }
        }
        .frame(width: 50, height: 50, alignment: .center)
        .cornerRadius(12)
    }
}
