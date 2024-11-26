//
//  Expense.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public struct Expense: Codable, Hashable, Identifiable {

    public var id: String? // Automatically generated ID by Firestore

    public var name: String
    public var amount: Double
    public var date: Timestamp
    public var paidBy: [String: Double]
    public let addedBy: String
    public var updatedBy: String
    public var imageUrl: String?
    public var splitTo: [String] // Reference to user ids involved in the split
    public var splitType: SplitType
    public var splitData: [String: Double]? // Use this to store percentage or share data
    public var isActive: Bool

    public init(name: String, amount: Double, date: Timestamp, paidBy: [String: Double], addedBy: String,
                updatedBy: String, imageUrl: String? = nil, splitTo: [String], splitType: SplitType = .equally,
                splitData: [String: Double]? = [:], isActive: Bool = true) {
        self.name = name
        self.amount = amount
        self.date = date
        self.paidBy = paidBy
        self.addedBy = addedBy
        self.updatedBy = updatedBy
        self.imageUrl = imageUrl
        self.splitTo = splitTo
        self.splitType = splitType
        self.splitData = splitData
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
        case date
        case paidBy = "paid_by"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case imageUrl = "image_url"
        case splitTo = "split_to"
        case splitType = "split_type"
        case splitData = "split_data"
        case isActive = "is_active"
    }

    // Calculated properties for better UI representation
    public var formattedAmount: String {
        return amount.formattedCurrency
    }
}

extension Expense {
    /// It will return member's total split amount from the total expense
    public func getTotalSplitAmountOf(member: String) -> Double {
        if !self.splitTo.contains(member) { return 0 }

        switch self.splitType {
        case .equally:
            return self.amount / Double(self.splitTo.count)
        case .fixedAmount:
            return self.splitData?[member] ?? 0
        case .percentage:
            let totalPercentage = self.splitData?.values.reduce(0, +) ?? 0
            return self.amount * (self.splitData?[member] ?? 0) / totalPercentage
        case .shares:
            let totalShares = self.splitData?.values.reduce(0, +) ?? 0
            return self.amount * ((self.splitData?[member] ?? 0) / totalShares)
        }
    }

    /// It will return the owing amount to the member for that expense that he have to get or pay back
    public func getCalculatedSplitAmountOf(member: String) -> Double {
        let paidAmount = self.paidBy[member] ?? 0
        let splitAmount = getTotalSplitAmountOf(member: member)

        if self.paidBy.keys.contains(member) {
            return paidAmount - (self.splitTo.contains(member) ? splitAmount : 0)
        } else if self.splitTo.contains(member) {
            return -splitAmount
        } else {
            return paidAmount
        }
    }
}

public enum SplitType: String, Codable, CaseIterable {
    case equally
    case fixedAmount
    case percentage
    case shares
}

/// Struct to hold combined expense and user information
public struct ExpenseWithUser: Hashable {
    public let expense: Expense
    public let user: AppUser

    public init(expense: Expense, user: AppUser) {
        self.expense = expense
        self.user = user
    }
}
