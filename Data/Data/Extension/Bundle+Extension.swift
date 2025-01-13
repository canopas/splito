//
//  Bundle+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 21/02/24.
//

import Foundation

private class UIBundleFakeClass {}

public extension Bundle {
    static var dataBundle: Bundle {
        return Bundle(for: UIBundleFakeClass.self)
    }
}
