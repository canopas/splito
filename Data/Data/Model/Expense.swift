//
//  Expense.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public struct Expense: Codable, Hashable, Identifiable {

    public var id: String? // Automatically generated ID by Firestore

    public var groupId: String?
    public var name: String
    public var amount: Double
    public var category: String? = "General"
    public var currencyCode: String? = Currency.defaultCurrency.code
    public var date: Timestamp
    public let addedBy: String
    public var updatedAt: Timestamp?
    public var updatedBy: String?
    public var note: String?
    public var imageUrl: String?
    public var splitType: SplitType
    public var splitTo: [String] // Reference to user ids involved in the split
    public var splitData: [String: Double]? // User Id with the split amount based on the split type
    public var paidBy: [String: Double] // [userId: paid amount]
    public var participants: [String]? = [] // List of user ids, Used for searching expenses by user
    public var isActive: Bool

    public init(groupId: String, name: String, amount: Double, category: String  = "General",
                currencyCode: String = Currency.defaultCurrency.code, date: Timestamp, addedBy: String,
                updatedAt: Timestamp? = nil, updatedBy: String? = nil, note: String? = nil, imageUrl: String? = nil,
                splitType: SplitType, splitTo: [String], splitData: [String: Double]? = nil, paidBy: [String: Double],
                participants: [String], isActive: Bool = true) {
        self.groupId = groupId
        self.name = name
        self.amount = amount
        self.category = category
        self.currencyCode = currencyCode
        self.date = date
        self.addedBy = addedBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.note = note
        self.imageUrl = imageUrl
        self.splitType = splitType
        self.splitTo = splitTo
        self.splitData = splitData
        self.paidBy = paidBy
        self.participants = participants
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case name
        case amount
        case currencyCode = "currency_code"
        case category
        case date
        case addedBy = "added_by"
        case updatedAt = "updated_at"
        case updatedBy = "updated_by"
        case note
        case imageUrl = "image_url"
        case splitType = "split_type"
        case splitTo = "split_to"
        case splitData = "split_data"
        case paidBy = "paid_by"
        case participants
        case isActive = "is_active"
    }

    // Calculated properties for better UI representation
    public var formattedAmount: String {
        return amount.formattedCurrency(currencyCode)
    }
}

extension Expense {
    /// It will return member's total split amount from the total expense
    public func getTotalSplitAmountOf(member: String) -> Double {
        if !self.splitTo.contains(member) { return 0 }

        switch self.splitType {
        case .equally:
            return calculateEqualSplitAmount(memberId: member, amount: self.amount, splitTo: self.splitTo)
        case .fixedAmount:
            return self.splitData?[member] ?? 0
        case .percentage:
            return calculatePercentageSplitAmount(memberId: member, amount: self.amount,
                                                  splitTo: self.splitTo, splitData: self.splitData ?? [:])
        case .shares:
            return calculateSharesSplitAmount(memberId: member, amount: self.amount,
                                              splitTo: self.splitTo, splitData: self.splitData ?? [:])
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
    public var expense: Expense
    public let user: AppUser

    public init(expense: Expense, user: AppUser) {
        self.expense = expense
        self.user = user
    }
}

public func calculateEqualSplitAmount(memberId: String, amount: Double, splitTo: [String]) -> Double {
    let totalMembers = Double(splitTo.count)
    let baseAmount = (amount / totalMembers).rounded(to: 2)    // Base amount each member owes
    let remainder = amount - (baseAmount * totalMembers)      // The leftover amount due to rounding
    let sortedMembers = splitTo.sorted() // Sort members deterministically for consistent assignment of remainder

    // Assign base amount to each member
    var splitAmounts: [String: Double] = [:]
    for splitMember in sortedMembers {
        splitAmounts[splitMember] = baseAmount
    }

    // Distribute remainder, if there is any, to the first member in the sorted list
    if let firstMember = sortedMembers.first, memberId == firstMember {
        splitAmounts[firstMember]! += remainder
    }

    return splitAmounts[memberId] ?? 0
}

public func calculatePercentageSplitAmount(memberId: String, amount: Double, splitTo: [String], splitData: [String: Double]) -> Double {
    let totalPercentage = splitData.values.reduce(0, +)
    if totalPercentage == 0 { return 0 }

    var splitAmounts: [String: Double] = [:]
    var totalUnroundedAmount = 0.0
    var totalRoundedAmount = 0.0
    var roundedSplitAmounts: [String: Double] = [:]
    let sortedMembers = splitTo.sorted()

    // Calculate unrounded amounts based on percentages
    for splitMember in splitTo {
        let percentage = Double(splitData[splitMember] ?? 0)
        let unroundedAmount = totalPercentage == 0 ? 0 : (amount * (percentage / totalPercentage))
        splitAmounts[splitMember] = unroundedAmount
        totalUnroundedAmount += unroundedAmount
    }

    // Round the unrounded amounts to 2 decimal places
    for (splitMember, unroundedAmount) in splitAmounts {
        let roundedAmount = unroundedAmount.rounded(to: 2)
        roundedSplitAmounts[splitMember] = roundedAmount
        totalRoundedAmount += roundedAmount
    }

    // Distribute remainder, if there is any, to the first member in the sorted list
    if let firstMember = sortedMembers.first, memberId == firstMember {
        let remainder = amount - totalRoundedAmount
        roundedSplitAmounts[firstMember]! += remainder
    }

    return roundedSplitAmounts[memberId] ?? 0
}

public func calculateSharesSplitAmount(memberId: String, amount: Double, splitTo: [String], splitData: [String: Double]) -> Double {
    let totalShares = splitData.values.reduce(0, +)
    if totalShares == 0 { return 0 }

    var totalRoundedAmount = 0.0
    var splitAmounts: [String: Double] = [:]
    let sortedMembers = splitTo.sorted()

    // Assign rounded share amounts to each member
    for splitMember in splitTo {
        let unroundedAmount = amount * (Double(splitData[splitMember] ?? 0) / totalShares)
        let roundedAmount = unroundedAmount.rounded(to: 2)
        splitAmounts[splitMember] = roundedAmount
        totalRoundedAmount += roundedAmount
    }

    // Distribute remainder, if there is any, to the first member in the sorted list
    if let firstMember = sortedMembers.first, memberId == firstMember {
        let remainder = amount - totalRoundedAmount
        splitAmounts[firstMember]! += remainder
    }

    return splitAmounts[memberId] ?? 0
}
