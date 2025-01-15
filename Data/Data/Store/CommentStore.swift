//
//  CommentStore.swift
//  Data
//
//  Created by Amisha Italiya on 10/01/25.
//

import FirebaseFirestore

class CommentStore: ObservableObject {

    private let COLLECTION_NAME: String = "groups"
    private let EXPENSES_COLLECTION: String = "expenses"
    private let TRANSACTIONS_COLLECTION: String = "transactions"
    private let EXPENSES_COMMENTS_COLLECTION: String = "expenses_comments"
    private let TRANSACTIONS_COMMENTS_COLLECTION: String = "transactions_comments"

    @Inject private var database: Firestore

    private func commentReference(groupId: String, parentId: String, isForExpenseComment: Bool = true) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(groupId)
            .collection(isForExpenseComment ? EXPENSES_COLLECTION : TRANSACTIONS_COLLECTION)
            .document(parentId)
            .collection(isForExpenseComment ? EXPENSES_COMMENTS_COLLECTION : TRANSACTIONS_COMMENTS_COLLECTION)
    }

    func addComment(groupId: String, parentId: String, comment: Comment, isForExpenseComment: Bool = true) async throws -> Comment? {
        let documentRef = commentReference(groupId: groupId, parentId: parentId, isForExpenseComment: isForExpenseComment).document()

        var newComment = comment
        newComment.id = documentRef.documentID

        do {
            try documentRef.setData(from: newComment)
        } catch {
            LogE("CommentStore: \(#function) Failed to add comment: \(error).")
            throw error
        }

        return newComment
    }

    func fetchCommentsBy(groupId: String, parentId: String, limit: Int, lastDocument: DocumentSnapshot?, isForExpenseComment: Bool = true) async throws -> (data: [Comment], lastDocument: DocumentSnapshot?) {
        var query = commentReference(groupId: groupId, parentId: parentId, isForExpenseComment: isForExpenseComment)
            .order(by: "commented_at", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments(source: .server)
        let comments = try snapshot.documents.compactMap { document in
            try document.data(as: Comment.self)
        }

        return (comments, snapshot.documents.last)
    }
}
