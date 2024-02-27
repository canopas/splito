//
//  String+Extension.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

extension String {
    public var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }

    public func getNumbersOnly() -> String {
        self.filter("0123456789".contains)
    }
}
