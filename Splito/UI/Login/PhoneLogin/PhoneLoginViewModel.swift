//
//  PhoneLoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data
import FirebaseAuth
import BaseStyle

public class PhoneLoginViewModel: BaseViewModel, ObservableObject {

    let MAX_NUMBER_LENGTH: Int = 20

    @Published var countries = [Country]()
    @Published var currentCountry: Country

    @Published private(set) var verificationId = ""
    @Published private(set) var showLoader: Bool = false

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

    // MARK: - Data Loading
    func verifyAndSendOtp() {
        showLoader = true
        FirebaseProvider.phoneAuthProvider
            .verifyPhoneNumber((currentCountry.dialCode + phoneNumber.getNumbersOnly()), uiDelegate: nil) { [weak self] (verificationID, error) in
                self?.showLoader = false
                if let error {
                    self?.handleFirebaseAuthErrors(error)
                } else {
                    self?.verificationId = verificationID ?? ""
                    self?.openVerifyOtpView()
                }
            }
    }

    // MARK: - User Actions
    func handleBackBtnTap() {
        router.pop()
    }

    func handlePrivacyPolicyTap() {
        if let url = URL(string: Constants.privacyPolicyURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            } else {
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Privacy policy cannot be accessed."))
            }
        }
    }
}

// MARK: - Helper Methods
extension PhoneLoginViewModel {

    private func openVerifyOtpView() {
        router.push(.VerifyOTPView(phoneNumber: phoneNumber, dialCode: currentCountry.dialCode, verificationId: verificationId))
    }

    private func handleFirebaseAuthErrors(_ error: Error) {
        if (error as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
            showAlertFor(message: "Something went wrong! Please try after some time.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
            showAlertFor(message: "Too many attempts, please try after some time.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number.")
        } else {
            LogE("Firebase: Phone login fail with error: \(error.localizedDescription)")
            showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
        }
    }
}
