/* eslint-disable */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { onGroupWrite } from './users_service/users_service'; 
import { onActivityCreate } from './notifications_service/notifications_service';
import { MailService } from './mail_service/mail_service';
import { SupportService } from './contact_support_service/contact_support_service';

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  try {
    admin.initializeApp();
    logger.info('Firebase app initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize Firebase app:', error);
    throw error;  // Re-throw to prevent function execution with uninitialized app
  }
} else {
  logger.debug('Firebase app already initialized');
}    

// Initialize MailService and SupportService
const mailService = new MailService();
const supportService = new SupportService(mailService);

// Cloud Function to send support emails via HTTP request
exports.sendSupportEmail = functions.https.onRequest(async (req, res) => {
  try {
    const supportData = req.body; // Assuming support data is sent in the body of the request
    if (!supportData) {
      res.status(400).send('Missing support data');
      return;
    }
    await supportService.onContactSupportCreated(supportData);
    res.status(200).send('Support email sent successfully');
  } catch (error) {
    logger.error('Error sending support email:', error);
    res.status(500).send('Error sending support email');
  }
});

exports.onGroupWrite = onGroupWrite;
exports.onActivityCreate = onActivityCreate;
