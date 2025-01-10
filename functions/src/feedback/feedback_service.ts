/* eslint-disable */

import { MailService } from "../mail/mail_service";

export class FeedbackService {
  private mailService: MailService;

  constructor(mailService: MailService) {
    this.mailService = mailService;
  }

  async onFeedbackCreated(support: any): Promise<any> {
    let body = "Feedback request created\n\n";

    for (const key of Object.keys(support)) {
      let value = support[key];

      // Check if the value is a Date object & Convert created_at to local (IST) time
      if (key === "created_at" && typeof value === "object") {
        const date = new Date(value.seconds * 1000);
        
        value = date.toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata", year: "numeric", month: "long", day: "numeric", 
          hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: true,
        });
      }

      // If the value is attachment urls separate them with a line break
      if (key === "attachment_urls" && Array.isArray(value)) {
        value = value.join("\n");
      }

      body += `${key}: ${value}\n`;
    }

    await this.mailService.sendEmail(
      ["contact@canopas.com"],
      "contact@canopas.com",
      "Splito: Feedback Request Created",
      body,
    );
  }
}