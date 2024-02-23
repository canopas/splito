//
//  PhoneLoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data

public class PhoneLoginViewModel: BaseViewModel, ObservableObject {

    let MAX_NUMBER_LENGTH: Int = 20

    @Published private(set) var verificationId = ""
    @Published var countries = [Country]()
    @Published var currentCountry: Country
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var currentState: ViewState = .initial

    @Published var phoneNumber = "" {
        didSet {
            guard phoneNumber.count < MAX_NUMBER_LENGTH else {
                showAlertFor(message: "Entered number is too long, Please check the phone number.")
                phoneNumber = oldValue
                return
            }
        }
    }

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router

        let allCountries = JSONUtils.readJSONFromFile(fileName: "Countries", type: [Country].self, bundle: .baseBundle) ?? []
        let currentLocal = Locale.current.region?.identifier
        self.countries = allCountries
        self.currentCountry = allCountries.first(where: {$0.isoCode == currentLocal}) ?? (allCountries.first ?? Country(name: "India", dialCode: "+91", isoCode: "IN"))
        super.init()
    }

    func verifyAndSendOtp() {

    }
}

// MARK: - Helper Methods
extension PhoneLoginViewModel {

    func openVerifyOtpView() {

    }

    func handleFirebaseAuthErrors(_ error: Error) {
//        if (error as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
//            showAlertFor(message: R.string.common.alert_message_something_went_wrong.localized())
//        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
//            showAlertFor(message: R.string.common.alert_message_too_many_attempts.localized())
//        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue {
//            showAlertFor(message: R.string.common.alert_message_enter_valid_number.localized())
//        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
//            showAlertFor(message: R.string.common.alert_message_enter_valid_number.localized())
//        } else {
//            LogE("Firebase: Phone login fail with error: \(error.localizedDescription)")
//            showAlertFor(title: R.string.common.authentication_failed_title.localized(), message: R.string.common.alert_message_authentication_failed.localized())
//        }
    }
}

// MARK: - View's State & Alert
extension PhoneLoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
