//
//  Bundle+Extension.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 21/02/24.
//

private class UIBundleFakeClass {}

public extension Bundle {
    static var baseBundle: Bundle {
        return Bundle(for: UIBundleFakeClass.self)
    }
}
