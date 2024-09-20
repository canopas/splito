//
//  BaseViewModel.swift
//  Data
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data
import Combine
import BaseStyle
import Network

@MainActor
open class BaseViewModel {

    @Published public var currentErrorState: BaseErrorState = .noError

    @Published public var toast: ToastPrompt?

    @Published public var alert: AlertPrompt = .init(message: "")
    @Published public var showAlert: Bool = false

    @Published var networkMonitor = NetworkMonitor()

    public var cancelable = Set<AnyCancellable>()

    public init() {
        if !networkMonitor.isConnected {
            currentErrorState = .noInternet
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// This will take error as argument and show error's description text as message with ok button.
    open func showAlertFor(_ error: Error) {
        // Check if the error is a ServiceError, otherwise handle as a generic error
        if let serviceError = error as? ServiceError {
            alert = .init(message: serviceError.descriptionText)
        } else {
            // Handle non-ServiceError cases with a default message or the localized description
            alert = .init(message: error.localizedDescription)
        }
        showAlert = true
    }

    /// Use this method when you want to show alert with title and message and default title is empty **""**.
    public func showAlertFor(title: String = "", message: String) {
        alert = .init(title: title, message: message)
        showAlert = true
    }

    /// This will take AlertPrompt as argument in which you can manage buttons and it's actions.
    public func showAlertFor(alert item: AlertPrompt) {
        alert = item
        showAlert = true
    }

    /// This will handle error state from error provided in argument.
    public func handleStateFor(_ error: ServiceError) {
        switch error {
        case .serverError:
            currentErrorState = .somethingWentWrong
        case .networkError:
            currentErrorState = .noInternet
        default:
            return
        }
    }

    /// Handle error thrown by firestore query
    public func handleServiceError(_ error: Error) {
        if !networkMonitor.isConnected {
            currentErrorState = .noInternet
        } else {
            // Check if the error is a ServiceError, otherwise handle as a generic error
            if let serviceError = error as? ServiceError {
                showToastFor(serviceError)
            } else {
                // Handle non-ServiceError cases with a default message or the localized description
                showToastFor(toast: .init(type: .error, title: "Error", message: error.localizedDescription))
            }
        }
    }

    /// Use this method to show error toast, pass an error as argument and it will show toast with title **Error** and message will be error's descriptionText.
    public func showToastFor(_ error: ServiceError) {
        toast = .init(type: .error, title: "Error", message: error.descriptionText)
    }

    /// Use this method to show toast with custom specificatons like title message and duration for toast.
    public func showToastFor(toast item: ToastPrompt) {
        toast = item
    }
}

public extension BaseViewModel {
    enum BaseErrorState: Equatable {
        public static func == (lhs: BaseViewModel.BaseErrorState, rhs: BaseViewModel.BaseErrorState) -> Bool {
            return lhs.key == rhs.key
        }

        case somethingWentWrong
        case noInternet
        case noError

        public var key: String {
            switch self {
            case .somethingWentWrong:
                return "somethingWentWrong"
            case .noInternet:
                return "noInternet"
            case .noError:
                return "noError"
            }
        }
    }
}

class NetworkMonitor: ObservableObject {

    private var monitor: NWPathMonitor
    private let queue = DispatchQueue.global(qos: .background)

    @Published var isConnected: Bool = true

    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
