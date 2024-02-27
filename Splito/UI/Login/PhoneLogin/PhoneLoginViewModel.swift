//
//  PhoneLoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data
import FirebaseAuth

public class PhoneLoginViewModel: BaseViewModel, ObservableObject {

    let MAX_NUMBER_LENGTH: Int = 20

    @Inject var router: Router<AppRoute>

    @Published var countries = [Country]()
    @Published var currentCountry: Country

    @Published private(set) var verificationId = ""
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

    override init() {
        let allCountries = JSONUtils.readJSONFromFile(fileName: "Countries", type: [Country].self, bundle: .baseBundle) ?? []
        let currentLocal = Locale.current.region?.identifier
        self.countries = allCountries
        self.currentCountry = allCountries.first(where: {$0.isoCode == currentLocal}) ?? (allCountries.first ?? Country(name: "India", dialCode: "+91", isoCode: "IN"))
        super.init()
    }

    func verifyAndSendOtp() {
        FirebaseProvider.phoneAuthProvider
            .verifyPhoneNumber((currentCountry.dialCode + phoneNumber.getNumbersOnly()), uiDelegate: nil) { [weak self] (verificationID, error) in
                self?.showLoader = false
                if let error {
                    self?.handleFirebaseAuthErrors(error)
                    self?.currentState = .initial
                } else {
                    self?.currentState = .initial
                    self?.verificationId = verificationID ?? ""
                    self?.openVerifyOtpView()
                }
            }
    }
}

// MARK: - Helper Methods
extension PhoneLoginViewModel {

    func openVerifyOtpView() {
        router.push(.VerifyOTPView(phoneNumber: phoneNumber, verificationId: verificationId))
    }

    func handleFirebaseAuthErrors(_ error: Error) {
        if (error as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
            showAlertFor(message: "Something went wrong! Please try after some time.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
            showAlertFor(message: "Too many attempts, please try after some time")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number")
        } else {
            LogE("Firebase: Phone login fail with error: \(error.localizedDescription)")
            showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
        }
    }
}

// MARK: - View's State & Alert
extension PhoneLoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
