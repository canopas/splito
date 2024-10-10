/* eslint-disable */

import { getFirestore, Firestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db: Firestore = getFirestore();

// Cloud Function to handle new expense creation and notify users
exports.onExpenseCreated = onDocumentCreated(
  { document: 'groups/{groupId}/expenses/{expenseId}' },
  async (event) => {
    try {
      const expenseData = event.data?.data();
      if (!expenseData) {
        logger.warn('No data found for the newly created expense.');
        return;
      }

      // Extract users who share the expense and the user who added it
      const splitToUsers = expenseData.split_to || [];
      const addedBy = expenseData.added_by;

      // Notify all users in splitTo except the one who added the expense
      for (const userId of splitToUsers) {
        if (userId !== addedBy) {
          await sendNotification(
            userId,
            `${expenseData.name} (₹${expenseData.amount.toFixed(2)})`,
            `- You owe (₹${expenseData.amount.toFixed(2)})`
          );
        }
      }

      logger.info(`Expense created notification sent successfully Expense Data: ${expenseData}`);
    } catch (error) {
      logger.error('Error in onExpenseCreated function:', error);
    }
  }
);

// Function to send notification using FCM
async function sendNotification(userId: string, title: string, body: string) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (userDoc.exists && userDoc.data()?.deviceFcmToken) { // Adjusted to use deviceFcmToken
      const fcmToken = userDoc.data()?.deviceFcmToken;

      const payload = {
        notification: {
          title,
          body,
        },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      logger.info(`Notification sent to user: ${userId}`);
    } else {
      logger.warn(`No FCM token found for user: ${userId}`);
    }
  } catch (error) {
    logger.error('Error sending notification:', error);
  }
}