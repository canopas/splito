/* eslint-disable */

import { getFirestore, Firestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db: Firestore = getFirestore();
const notificationTitle = `Splito`;

// Cloud Function to observe new activity documents in the user's activity subcollection
exports.onActivityCreated = onDocumentCreated(
  { document: 'users/{userId}/activity/{activityId}' },
  async (event) => {
    try {
      const activityData = event.data?.data();
      if (!activityData) {
        logger.warn('No data found for the newly created activity.');
        return;
      }

      const userId = event.params.userId;
      const activityMessage = generateNotificationMessage(activityData);

      await sendNotification(userId, notificationTitle, activityMessage, event.params.activityId);
      logger.info(`Notification processed for activity ${activityData.activity_id} for user ${userId}`);
    } catch (error) {
      logger.error('Error in onActivityCreated function:', error);
    }
  }
);

// Helper function to generate notification message based on activity type and amount
function generateNotificationMessage(activityData: admin.firestore.DocumentData) {
  const amount = activityData.amount;
  const message = generateAmountMessage(amount);
  const actionUserName = activityData.action_user_name;
  const payer = activityData.amount > 0 ? "You" : actionUserName;
  const receiver = activityData.amount < 0 ? "you" : actionUserName;
  const groupName = activityData.group_name;
  
  switch (activityData.type) {
    case 'group_created':
      return `${actionUserName} created the group "${groupName}"`;

    case 'group_updated':
      return `${actionUserName} updated the group name from "${activityData.previous_group_name}" to "${groupName}" and changed the cover photo`;

    case 'group_deleted':
      return `${actionUserName} deleted the group "${groupName}"`;

    case 'group_restored':
      return `${actionUserName} restored the group "${groupName}"`;

    case 'group_name_updated':
      return `${actionUserName} updated the group name from "${activityData.previous_group_name}" to "${groupName}"`;

    case 'group_image_updated':
      return `${actionUserName} changed the cover photo for "${groupName}"`;

    case 'group_member_left':
      return `${actionUserName} left the group "${groupName}"`;
            
    case 'group_member_removed':
      return `${actionUserName} removed ${activityData.removed_member_name} from the group "${groupName}"`;

    case 'expense_added':
      return `${activityData.expense_name} \n${message}`;

    case 'expense_updated':
      return `Expense updated: ${activityData.expense_name} \n${message}`;

    case 'expense_deleted':
      return `Expense deleted: ${activityData.expense_name} \n${message}`;

    case 'expense_restored':
      return `Expense restored: ${activityData.expense_name} \n${message}`;

    case 'transaction_added':
      return `${payer} paid ${receiver} ${formatCurrency(Math.abs(amount))}`;

    case 'transaction_updated':
      return `Payment updated: ${payer} paid ${receiver} ${formatCurrency(Math.abs(amount))}`;

    case 'transaction_deleted':
      return `Payment deleted: ${payer} paid ${receiver} ${formatCurrency(Math.abs(amount))}`;

    case 'transaction_restored':
      return `Payment restored: ${payer} paid ${receiver} ${formatCurrency(Math.abs(amount))}`;

    default:
      return `New activity detected.`;
  }
}

// Helper function to generate notification message based on owedAmount
function generateAmountMessage(owedAmount: number): string {
  if (owedAmount < 0) { 
    return `- You owe ${formatCurrency(Math.abs(owedAmount))}`; 
  } else if (owedAmount > 0) { 
    return `- You get back ${formatCurrency(owedAmount)}`;
  } else {
    return `- You do not owe anything`;
  }
}

// Helper function to format currency
function formatCurrency(amount: number) {
  const formatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' });
  return formatter.format(amount);
}

// Function to send notification using FCM
async function sendNotification(userId: string, title: string, body: string, activityId: string) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userDoc.exists && userData?.device_fcm_token) {
      const fcmToken = userData.device_fcm_token;

      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          activityId: activityId || "",
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