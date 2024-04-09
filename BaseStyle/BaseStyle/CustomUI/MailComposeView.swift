//
//  MailComposeView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 08/04/24.
//

import UIKit
import SwiftUI
import MessageUI

public struct MailComposeView: UIViewControllerRepresentable {

    let logFilePath: URL?
    var showToast: () -> Void

    public init(logFilePath: URL?, showToast: @escaping () -> Void) {
        self.logFilePath = logFilePath
        self.showToast = showToast
    }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        guard MFMailComposeViewController.canSendMail() else {
            print("MailComposeView: Device cannot send email.")
            return MFMailComposeViewController()
        }

        let mailComposeViewController = MFMailComposeViewController()
        mailComposeViewController.setSubject("Log File")
        mailComposeViewController.setMessageBody("Please find the attached logfile.", isHTML: false)
        mailComposeViewController.mailComposeDelegate = context.coordinator

        if let logFilePath {
            do {
                let attachmentData = try Data(contentsOf: logFilePath)
                mailComposeViewController.addAttachmentData(attachmentData, mimeType: "application/zip", fileName: "logs.zip")
            } catch {
                print("MailComposeView: Failed to load attachment data: \(error.localizedDescription)")
            }
        }

        // Set default recipient email address
        mailComposeViewController.setToRecipients(["contact@canopas.com"])

        return mailComposeViewController
    }

    public func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }

    public func makeCoordinator() -> Coordinator {
        Coordinator(showToast: showToast)
    }
}

public class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    var showToast: () -> Void

    public init(showToast: @escaping () -> Void) {
        self.showToast = showToast
    }

    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: (any Error)?) {
        var needToShowToast = false
        switch result {
        case .sent:
            needToShowToast = true
        default:
            break
        }

        controller.dismiss(animated: true) {
            if needToShowToast {
                self.showToast()
            }
        }
    }
}
