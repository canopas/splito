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

    @Published var networkMonitor = NetworkMonitor()

    @Published public var toast: ToastPrompt?

    @Published public var alert: AlertPrompt = .init(message: "")
    @Published public var showAlert: Bool = false

    public var cancelable = Set<AnyCancellable>()

    public init() {}

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    /// Use this method to show error toast and it will show toast with title **Error** and message.
    public func showToastForError() {
        if !networkMonitor.isConnected {
            showToastFor(toast: .init(type: .error, title: "Error", message: "No internet connection!"))
        } else {
            showToastFor(toast: .init(type: .error, title: "Error", message: "Something went wrong."))
        }
    }

    /// Use this method to show toast with custom specificatons like title message and duration for toast.
    public func showToastFor(toast item: ToastPrompt) {
        toast = item
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
