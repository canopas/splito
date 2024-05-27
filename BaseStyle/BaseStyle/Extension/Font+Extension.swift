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

    /// It's default **size: 28** and weight is **Semi bold**
    static func H1Text(_ size: CGFloat = 28) -> Font {
        .custom(InterFontStyle.bold.name, size: size)
    }

    /// It's default **size: 24** and weight is **Semi bold**
    static func H2Text(_ size: CGFloat = 24) -> Font {
        .custom(InterFontStyle.semiBold.name, size: size)
    }

    /// It's default **size: 20** and weight is **Medium**
    static func H3Text(_ size: CGFloat = 20) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 24** and weight is **Bold**
    static func Header(_ size: CGFloat = 24) -> Font {
        .custom(InterFontStyle.bold.name, size: size)
    }

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

    /// It's default **size: 14** and weight is **Medium**
    static func subTitle3(_ size: CGFloat = 14) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 12** and weight is **Bold**
    static func subTitle4(_ size: CGFloat = 12) -> Font {
        .custom(InterFontStyle.bold.name, size: size)
    }

    /// It's default **size: 12** and weight is **Medium**
    static func caption1(_ size: CGFloat = 12) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 16** and weight is **Regular**
    static func body1(_ size: CGFloat = 16) -> Font {
        .custom(InterFontStyle.regular.name, size: size)
    }

    /// It's default **size: 14** and weight is **Medium**
    static func body2(_ size: CGFloat = 14) -> Font {
        .custom(InterFontStyle.medium.name, size: size)
    }

    /// It's default **size: 16** and weight is **SemiBold**
    static func bodyBold(_ size: CGFloat = 16) -> Font {
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

public extension UIFont {
    static func inter(_ style: InterFontStyle, size: CGFloat) -> UIFont? {
        switch style {
        case .regular:
            return UIFont(name: InterFontStyle.regular.name, size: size)
        case .medium:
            return UIFont(name: InterFontStyle.medium.name, size: size)
        case .bold:
            return UIFont(name: InterFontStyle.bold.name, size: size)
        case .semiBold:
            return UIFont(name: InterFontStyle.semiBold.name, size: size)
        case .thin:
            return UIFont(name: InterFontStyle.thin.name, size: size)
        case .light:
            return UIFont(name: InterFontStyle.light.name, size: size)
        case .italic:
            return UIFont(name: InterFontStyle.italic.name, size: size)
        case .mediumItalic:
            return UIFont(name: InterFontStyle.mediumItalic.name, size: size)
        case .semiBoldItalic:
            return UIFont(name: InterFontStyle.semiBoldItalic.name, size: size)
        case .heavyItalic:
            return UIFont(name: InterFontStyle.heavyItalic.name, size: size)
        }
    }
}

extension Font {
    private static func registerFont(withName name: String, fileExtension: String, bundle: Bundle? = Bundle.baseBundle) {
        let frameworkBundle = bundle ?? Bundle.baseBundle
        let pathForResourceString = frameworkBundle.path(forResource: name, ofType: fileExtension)
        let fontData = NSData(contentsOfFile: pathForResourceString!)
        let dataProvider = CGDataProvider(data: fontData!)
        let fontRef = CGFont(dataProvider!)
        var errorRef: Unmanaged<CFError>?

        if CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false {
            print("Error registering font")
        }
    }

    // Register all font to use in frame work
    public static func loadFonts() {
        registerFont(withName: "Inter-Regular", fileExtension: "ttf")
        registerFont(withName: "Inter-Bold", fileExtension: "ttf")
        registerFont(withName: "Inter-Thin", fileExtension: "ttf")
        registerFont(withName: "Inter-SemiBold", fileExtension: "ttf")
        registerFont(withName: "Inter-Medium", fileExtension: "ttf")
        registerFont(withName: "Inter-Light", fileExtension: "ttf")
        registerFont(withName: "Acme-Regular", fileExtension: "ttf")
        registerFont(withName: "Inter-Italic", fileExtension: "ttf")
        registerFont(withName: "inter-medium-italic", fileExtension: "ttf")
        registerFont(withName: "inter-heavy-italic", fileExtension: "otf")
        registerFont(withName: "inter-semi-bold-italic", fileExtension: "ttf")
    }
}
