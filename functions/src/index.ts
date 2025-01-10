/* eslint-disable */
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

import { onGroupWrite } from './users/users_service';
import { onActivityCreate } from './notifications/notifications_service';
import { FeedbackService } from "./feedback/feedback_service";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { MailService } from './mail/mail_service';

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

const mailService = new MailService();
const REGION = "asia-south1";
const feedbackService = new FeedbackService(mailService);

exports.onGroupWrite = onGroupWrite;
exports.onActivityCreate = onActivityCreate;

export const feedbackCreateObserver = onDocumentCreated(
  { region: REGION, document: "feedbacks/{feedbackId}" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("No data associated with the event");
      return;
    }
    const data = snapshot.data();

    try {
      await feedbackService.onFeedbackCreated(data);
    } catch (error) {
      logger.error('Error handling feedback:', error);
    }
  }
);