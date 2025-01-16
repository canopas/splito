//
//  CommentTextFieldView.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 13/01/25.
//

import SwiftUI

public struct CommentTextFieldView: View {

    @Binding var comment: String
    @Binding var showLoader: Bool
    var isFocused: FocusState<Bool>.Binding

    let onSendCommentBtnTap: () -> Void

    public init(comment: Binding<String>, showLoader: Binding<Bool>,
                isFocused: FocusState<Bool>.Binding, onSendCommentBtnTap: @escaping () -> Void) {
        self._comment = comment
        self._showLoader = showLoader
        self.isFocused = isFocused
        self.onSendCommentBtnTap = onSendCommentBtnTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(dividerColor)

            HStack(alignment: .center, spacing: 8) {
                TextField("Add a comment", text: $comment, axis: .vertical)
                    .font(.body1())
                    .foregroundStyle(primaryText)
                    .tint(primaryColor)
                    .focused(isFocused)
                    .textInputAutocapitalization(.sentences)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(outlineColor, lineWidth: 1)
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 8)
                    .lineLimit(3)

                CommentSendBtnView(showLoader: $showLoader, onClick: onSendCommentBtnTap)
                    .disabled(comment.trimming(spaces: .leadingAndTrailing).isEmpty)
            }
        }
    }
}

private struct CommentSendBtnView: View {

    @Binding var showLoader: Bool

    let onClick: () -> Void

    var body: some View {
        if !showLoader {
            Button(action: onClick) {
                Image(.sendIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(8)
                    .overlay(content: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(container2Color)
                    })
                    .padding(.trailing, 16)
            }
        } else {
            ImageLoaderView()
                .padding(12)
        }
    }
}
