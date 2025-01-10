/* eslint-disable */

import { SendEmailCommand, SESClient } from "@aws-sdk/client-ses";
require('dotenv').config()

export class MailService {
  private sesClient: SESClient;

  constructor() {
    const AWS_ACCESS_KEY_ID = process.env.AWS_ACCESS_KEY_ID;
    const AWS_SECRET_ACCESS_KEY = process.env.AWS_SECRET_ACCESS_KEY;
    const REGION = "ap-south-1";

    // Check if the necessary credentials are present before initializing the client
    if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY) {
      throw new Error('AWS credentials are missing. Please provide AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY');
    }

    this.sesClient = new SESClient({
      credentials: {
        accessKeyId: AWS_ACCESS_KEY_ID,
        secretAccessKey: AWS_SECRET_ACCESS_KEY,
      },
      region: REGION,
    });
  }

  private createSendEmailCommand(toAddresses: string[], fromAddress: string, subject: string, body: string): SendEmailCommand {
    return new SendEmailCommand({
      Destination: {
        CcAddresses: [
        ],
        ToAddresses: toAddresses,
      },
      Message: {
        Body: {
          Text: {
            Charset: "UTF-8",
            Data: body,
          },
        },
        Subject: {
          Charset: "UTF-8",
          Data: subject,
        },
      },
      Source: fromAddress,
      ReplyToAddresses: [
      ],
    });
  }

  async sendEmail(to: string[], from: string, subject: string, body: string): Promise<void> {
    const mail = this.createSendEmailCommand(to, from, subject, body);
    await this.sesClient.send(mail);
  }
}