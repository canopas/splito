//
//  Font+Extension.swift
//  UI
//
//  Created by Amisha Italiya on 16/02/24.
//

import SwiftUI

public enum InterFontStyle {
    case regular, medium, bold, semiBold, thin, light, italic, mediumItalic, semiBoldItalic, heavyItalic

    public var name: String {
        switch self {
        case .regular:
            return "Inter-Regular"
        case .medium:
            return "Inter-Medium"
        case .bold:
            return "Inter-Bold"
        case .semiBold:
            return "Inter-SemiBold"
        case .thin:
            return "Inter-Thin"
        case .light:
            return "Inter-Light"
        case .italic:
            return "Inter-Italic"
        case .mediumItalic:
            return "Inter-MediumItalic"
        case .semiBoldItalic:
            return "Inter-SemiBoldItalic"
        case .heavyItalic:
            return "Inter-HeavyItalic"
        }
    }
}

public extension Font {

    /// It's default **size: 24** and weight is **Semi bold**
    static func Header1(_ size: CGFloat = 24) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 22** and weight is **Semi bold**
    static func Header2(_ size: CGFloat = 22) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 20** and weight is **Semi bold**
    static func Header3(_ size: CGFloat = 20) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 18** and weight is **Semi bold**
    static func Header4(_ size: CGFloat = 18) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 14** and weight is **Semi bold**
    static func buttonText(_ size: CGFloat = 14) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 18** and weight is **Medium**
    static func subTitle1(_ size: CGFloat = 18) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 16** and weight is **Medium**
    static func subTitle2(_ size: CGFloat = 16) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 12** and weight is **Medium**
    static func caption1(_ size: CGFloat = 12) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 15** and weight is **Regular**
    static func body1(_ size: CGFloat = 15) -> Font {
        .custom(InterFontStyle.regular.name, size: size)
    }

    /// It's default **size: 14** and weight is **Medium**
    static func body2(_ size: CGFloat = 14) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 15** and weight is **SemiBold**
    static func bodyBold(_ size: CGFloat = 15) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 18** and weight is **Light**
    static func subTitleLight(_ size: CGFloat = 18) -> Font {
        .custom(InterFontStyle.light.name, size: size)
    }

    /// It will give inter font with provided font weight and size
    static func inter(_ style: InterFontStyle, size: CGFloat) -> Font {
        .custom(style.name, size: size)
    }

    /// It will give inter font with provided font weight and **fixedSize** , Fixed font size **stays the same regardless of user preference.**
    static func inter(_ style: InterFontStyle, fixedSize: CGFloat) -> Font {
        .custom(style.name, fixedSize: fixedSize)
    }
}
