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
    public var updatedAt: Timestamp
    public var paidBy: [String: Double]
    public let addedBy: String
    public var updatedBy: String
    public var note: String?
    public var imageUrl: String?
    public var splitTo: [String] // Reference to user ids involved in the split
    public var splitType: SplitType
    public var splitData: [String: Double]? // Use this to store percentage or share data
    public var isActive: Bool

    public init(name: String, amount: Double, date: Timestamp, updatedAt: Timestamp = Timestamp(), paidBy: [String: Double],
                addedBy: String, updatedBy: String, note: String? = nil, imageUrl: String? = nil, splitTo: [String],
                splitType: SplitType = .equally, splitData: [String: Double]? = [:], isActive: Bool = true) {
        self.name = name
        self.amount = amount
        self.date = date
        self.updatedAt = updatedAt
        self.paidBy = paidBy
        self.addedBy = addedBy
        self.updatedBy = updatedBy
        self.note = note
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
        case updatedAt = "updated_at"
        case paidBy = "paid_by"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case note = "note"
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
            return calculateEqualSplitAmount(for: member)
        case .fixedAmount:
            return self.splitData?[member] ?? 0
        case .percentage:
            return calculatePercentageSplitAmount(for: member)
        case .shares:
            return calculateSharesSplitAmount(for: member)
        }
    }

    /// Returns the equal split amount for the member
    private func calculateEqualSplitAmount(for member: String) -> Double {
        let totalMembers = Double(self.splitTo.count)
        let baseAmount = (self.amount / totalMembers).rounded(to: 2)    // Base amount each member owes
        let totalSplitAmount = baseAmount * totalMembers    // The total split amount after rounding all members base amounts
        let remainder = self.amount - totalSplitAmount      // The leftover amount due to rounding

        // Sort members deterministically to ensure consistent assignment of the remainder
        let sortedMembers = self.splitTo.sorted()

        // Assign base amount to each member
        var splitAmounts: [String: Double] = [:]
        for splitMember in sortedMembers {
            splitAmounts[splitMember] = baseAmount
        }

        // Distribute remainder, if there is any, to the first member in the sorted list
        if let firstMember = sortedMembers.first, member == firstMember {
            splitAmounts[firstMember]! += remainder
        }

        return splitAmounts[member] ?? 0
    }

    func calculatePercentageSplitAmount(for member: String) -> Double {
        let totalPercentage = self.splitData?.values.reduce(0, +) ?? 0
        if totalPercentage == 0 { return 0 }

        var splitAmounts: [String: Double] = [:]
        var totalUnroundedAmount = 0.0

        // Calculate unrounded amounts based on percentage
        for splitMember in self.splitTo {
            let percentage = Double(self.splitData?[splitMember] ?? 0)
            let unroundedAmount = totalPercentage == 0 ? 0 : (self.amount * (percentage / totalPercentage))
            splitAmounts[splitMember] = unroundedAmount
            totalUnroundedAmount += unroundedAmount
        }

        // Round the unrounded amounts to 2 decimal places
        var totalRoundedAmount = 0.0
        var roundedSplitAmounts: [String: Double] = [:]

        for (splitMember, unroundedAmount) in splitAmounts {
            let roundedAmount = unroundedAmount.rounded(to: 2)
            roundedSplitAmounts[splitMember] = roundedAmount
            totalRoundedAmount += roundedAmount
        }

        // Calculate the remainder to ensure the total matches the expenseAmount
        let remainder = self.amount - totalRoundedAmount

        // Distribute the remainder to the first member in the sorted list
        let sortedMembers = self.splitTo.sorted()

        if let firstMember = sortedMembers.first, member == firstMember {
            roundedSplitAmounts[firstMember]! += remainder
        }

        return roundedSplitAmounts[member] ?? 0
    }

    func calculateSharesSplitAmount(for member: String) -> Double {
        let totalShares = self.splitData?.values.reduce(0, +) ?? 0
        if totalShares == 0 { return 0 }

        var totalRoundedAmount = 0.0
        var splitAmounts: [String: Double] = [:]

        // Assign rounded share amounts to each member
        for splitMember in self.splitTo {
            let unroundedAmount = self.amount * (Double(self.splitData?[splitMember] ?? 0) / totalShares)
            let roundedAmount = unroundedAmount.rounded(to: 2)
            splitAmounts[splitMember] = roundedAmount
            totalRoundedAmount += roundedAmount
        }

        // Calculate remainder (difference between totalRoundedAmount and the original expenseAmount)
        let remainder = self.amount - totalRoundedAmount

        // Distribute remainder to the first member in the sorted list (or other consistent rule)
        let sortedMembers = self.splitTo.sorted()

        if let firstMember = sortedMembers.first, member == firstMember {
            splitAmounts[firstMember]! += remainder
        }

        return splitAmounts[member] ?? 0
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
    public var expense: Expense
    public let user: AppUser

    public init(expense: Expense, user: AppUser) {
        self.expense = expense
        self.user = user
    }
}
