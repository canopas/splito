//
//  CommentListView.swift
//  Splito
//
//  Created by Amisha Italiya on 13/01/25.
//

import SwiftUI
import BaseStyle
import Data

struct CommentListView: View {

    @Inject private var preference: SplitoPreference

    let comments: [Comment]
    let membersData: [AppUser]
    let hasMoreComments: Bool

    let loadMoreComments: (() -> Void)

    var body: some View {
        if !comments.isEmpty {
            SectionHeaderView(text: "Comments")

            ForEach(comments.uniqued(), id: \.id) { comment in
                var memberName: String {
                    let user = getMemberDataBy(id: comment.commentedBy)
                    return preference.user?.id == user?.id ? "You" : user?.fullName ?? "Someone"
                }

                ExpenseCommentCellView(comment: comment, memberName: memberName,
                                       memberProfileUrl: getMemberDataBy(id: comment.commentedBy)?.imageUrl,
                                       isLastComment: comments.last?.id == comment.id)
                .id(comment.id)

                if comments.last?.id == comment.id && hasMoreComments {
                    ProgressView()
                        .onAppear(perform: loadMoreComments)
                }
            }
        }
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return membersData.first(where: { $0.id == id })
    }
}

private struct ExpenseCommentCellView: View {

    let comment: Comment
    let memberName: String
    let memberProfileUrl: String?
    let isLastComment: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemberProfileImageView(imageUrl: memberProfileUrl)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(memberName)
                        .font(.body1())
                        .foregroundColor(primaryText)

                    Text("•")
                        .font(.caption1())
                        .foregroundColor(lowestText)

                    Text(comment.commentedAt.dateValue().getFormattedPastTime())
                        .font(.caption1())
                        .foregroundColor(lowestText)
                }

                Text(comment.comment)
                    .font(.caption1())
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        if !isLastComment {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}
