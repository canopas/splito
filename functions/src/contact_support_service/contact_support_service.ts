/* eslint-disable */

import { MailService } from "../mail_service/mail_service";

// Define a type for support request (You can adjust this according to the structure)
interface SupportRequest {
  [key: string]: string | number;  // Adjust types as per your data structure
}

export class SupportService {
  private mailService: MailService;

  constructor(mailService: MailService) {
    this.mailService = mailService;
  }

  async onContactSupportCreated(support: SupportRequest): Promise<void> {
    let body = "Support request created\n\n";

    // Using Object.entries to iterate through the support object
    for (const [key, value] of Object.entries(support)) {
      body += `${key}: ${value}\n`;
    }

    try {
      // Send email to the admin/support email
      await this.mailService.sendEmail(
        ["nirali.s@canopas.com"],  // Admin email
        "no-reply@canbook.in",  // From email
        "Splito: Contact support Request Created",
        body,
      );
    } catch (error) {
      console.error("Error sending contact support request email:", error);
      // Handle retry or logging mechanism
    }
  }
}