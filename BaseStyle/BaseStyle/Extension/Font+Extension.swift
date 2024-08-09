//
//  Font+Extension.swift
//  UI
//
//  Created by Amisha Italiya on 16/02/24.
//

import SwiftUI

public enum FontStyle {
    case robotoBold, robotoMedium, latoSemiBold, latoMedium, latoRegular

    public var name: String {
        switch self {
        case .robotoBold:
            "Roboto-Bold"
        case .robotoMedium:
            "Roboto-Medium"
        case .latoSemiBold:
            "Lato-SemiBold"
        case .latoMedium:
            "Lato-Medium"
        case .latoRegular:
            "Lato-Regular"
        }
    }
}

public extension Font {

    /// It's default **size: 26** and weight is **RobotoBold**
    static func Header1(_ size: CGFloat = 26) -> Font {
        .custom(FontStyle.robotoBold.name, size: size)
    }

    /// It's default **size: 22** and weight is **RobotoBold**
    static func Header2(_ size: CGFloat = 22) -> Font {
        .custom(FontStyle.robotoBold.name, size: size)
    }

    /// It's default **size: 20** and weight is **RobotoMedium**
    static func Header3(_ size: CGFloat = 20) -> Font {
        .custom(FontStyle.robotoMedium.name, size: size)
    }

    /// It's default **size: 18** and weight is **RobotoMedium**
    static func Header4(_ size: CGFloat = 18) -> Font {
        .custom(FontStyle.robotoMedium.name, size: size)
    }

    /// It's default **size: 18** and weight is **LatoMedium**
    static func subTitle1(_ size: CGFloat = 18) -> Font {
        .custom(FontStyle.latoMedium.name, size: size)
    }

    /// It's default **size: 16** and weight is **LatoMedium**
    static func subTitle2(_ size: CGFloat = 16) -> Font {
        .custom(FontStyle.latoMedium.name, size: size)
    }

    /// It's default **size: 16** and weight is **LatoRegular**
    static func subTitle3(_ size: CGFloat = 16) -> Font {
        .custom(FontStyle.latoRegular.name, size: size)
    }

    /// It's default **size: 15** and weight is **LatoMedium**
    static func body1(_ size: CGFloat = 15) -> Font {
        .custom(FontStyle.latoMedium.name, size: size)
    }

    /// It's default **size: 14** and weight is **LatoMedium**
    static func body2(_ size: CGFloat = 14) -> Font {
        .custom(FontStyle.latoMedium.name, size: size)
    }

    /// It's default **size: 14** and weight is **LatoRegular**
    static func body3(_ size: CGFloat = 14) -> Font {
        .custom(FontStyle.latoRegular.name, size: size)
    }

    /// It's default **size: 14** and weight is **LatoSemiBold**
    static func buttonText(_ size: CGFloat = 14) -> Font {
        .custom(FontStyle.latoSemiBold.name, size: size)
    }

    /// It's default **size: 13** and weight is **LatoMedium**
    static func caption1(_ size: CGFloat = 13) -> Font {
        .custom(FontStyle.latoMedium.name, size: size)
    }

    /// It will give font with provided font weight and size
    static func customFont(_ style: FontStyle, size: CGFloat) -> Font {
        .custom(style.name, size: size)
    }

    /// It will give font with provided font weight and **fixedSize** , Fixed font size **stays the same regardless of user preference.**
    static func customFont(_ style: FontStyle, fixedSize: CGFloat) -> Font {
        .custom(style.name, fixedSize: fixedSize)
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
        registerFont(withName: "Roboto-Bold", fileExtension: "ttf")
        registerFont(withName: "Roboto-Medium", fileExtension: "ttf")
        registerFont(withName: "Lato-SemiBold", fileExtension: "ttf")
        registerFont(withName: "Lato-Medium", fileExtension: "ttf")
        registerFont(withName: "Lato-Regular", fileExtension: "ttf")
    }
}
