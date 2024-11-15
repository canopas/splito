/* eslint-disable */

import { getFirestore, Firestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import messages from '../locales/en.json';

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db: Firestore = getFirestore();

const notificationTitle = messages.splito;
const currencyFormatter = new Intl.NumberFormat(
  process.env.LOCALE || 'en-IN',
  { style: 'currency', currency: process.env.CURRENCY || 'INR' }
);
  
 // TypeScript interface for user data in the users document
 interface UserData {
  device_fcm_token?: string;
}

 // TypeScript interface for activity data in the activity document
interface ActivityData {
  activity_id: string;
  type: 'group_created' | 'group_updated' | 'group_deleted' | 'group_restored' |
        'group_name_updated' | 'group_image_updated' | 'group_member_left' |
        'group_member_removed' | 'expense_added' | 'expense_updated' |
        'expense_deleted' | 'expense_restored' | 'transaction_added' |
        'transaction_updated' | 'transaction_deleted' | 'transaction_restored';
  action_user_name: string;
  group_name: string;
  previous_group_name?: string;
  removed_member_name?: string;
  expense_name?: string;
  payer_name?: string;
  receiver_name?: string
  amount?: number;
}

// Helper function to format currency
function formatCurrency(amount: number) {
  if (!Number.isFinite(amount)) {
    logger.warn(`Invalid amount provided for formatting: ${amount}`);
    return currencyFormatter.format(0);
  }
  return currencyFormatter.format(amount);
}

// Cloud Function to observe new activity documents in the user's activity collection
export const onActivityCreate = onDocumentCreated(
  { document: 'users/{userId}/activity/{activityId}' },
  async (event) => {
    try {
      const activityData = event.data?.data() as ActivityData;
      if (!activityData) {
        logger.warn('No data found for the newly created activity.');
        return;
      }

      const userId = event.params.userId;
      const activityMessage = generateNotificationMessage(activityData);

      await sendNotification(userId, notificationTitle, activityMessage, event.params.activityId);
      logger.info(`Notification processed for activity ${event.params.activityId} for user ${userId}`);
    } catch (error) {
      logger.error('Error in onActivityCreate function:', error);
    }
  }
);

// Helper function to generate notification message based on activity type
function generateNotificationMessage(activityData: ActivityData) {
  const amount = activityData.amount ?? 0;
  const amountMessage = generateAmountMessage(amount);
  const expenseName = activityData.expense_name ?? messages.unknown;
  const actionUserName = activityData.action_user_name;
  const payerName = activityData.payer_name ?? messages.someone;
  const receiverName = activityData.receiver_name ?? messages.someone;
  const groupName = activityData.group_name;
  const previousGroupName = activityData.previous_group_name ?? messages.unknown;

  switch (activityData.type) {
    case 'group_created':
      return messages.group_created.replace("{actionUserName}", actionUserName).replace("{groupName}", groupName);

    case 'group_updated':
      return messages.group_updated.replace("{actionUserName}", actionUserName).replace("{previousGroupName}", previousGroupName).replace("{groupName}", groupName);

    case 'group_deleted':
      return messages.group_deleted.replace("{actionUserName}", actionUserName).replace("{groupName}", groupName);

    case 'group_restored':
      return messages.group_restored.replace("{actionUserName}", actionUserName).replace("{groupName}", groupName);

    case 'group_name_updated':
      return messages.group_name_updated.replace("{actionUserName}", actionUserName).replace("{previousGroupName}", previousGroupName).replace("{groupName}", groupName);

    case 'group_image_updated':
      return messages.group_image_updated.replace("{actionUserName}", actionUserName).replace("{groupName}", groupName);

    case 'group_member_left':
      return messages.group_member_left.replace("{actionUserName}", actionUserName).replace("{groupName}", groupName);
            
    case 'group_member_removed':
      return messages.group_member_removed.replace("{actionUserName}", actionUserName).replace("{removedMemberName}", activityData.removed_member_name ?? '').replace("{groupName}", groupName);

    case 'expense_added':
      return messages.expense_added.replace("{expenseName}", expenseName).replace("{amountMessage}", amountMessage);

    case 'expense_updated':
      return messages.expense_updated.replace("{expenseName}", expenseName).replace("{amountMessage}", amountMessage);

    case 'expense_deleted':
      return messages.expense_deleted.replace("{expenseName}", expenseName).replace("{amountMessage}", amountMessage);

    case 'expense_restored':
      return messages.expense_restored.replace("{expenseName}", expenseName).replace("{amountMessage}", amountMessage);

    case 'transaction_added':
      return messages.transaction_added.replace("{payerName}", payerName).replace("{receiverName}", receiverName).replace("{amountMessage}", formatCurrency(Math.abs(amount)));

    case 'transaction_updated':
      return messages.transaction_updated.replace("{payerName}", payerName).replace("{receiverName}", receiverName).replace("{amountMessage}", formatCurrency(Math.abs(amount)));

    case 'transaction_deleted':
      return messages.transaction_deleted.replace("{payerName}", payerName).replace("{receiverName}", receiverName).replace("{amountMessage}", formatCurrency(Math.abs(amount)));

    case 'transaction_restored':
      return messages.transaction_restored.replace("{payerName}", payerName).replace("{receiverName}", receiverName).replace("{amountMessage}", formatCurrency(Math.abs(amount)));

    default:
      return messages.new_activity;
  }
}

// Helper function to generate notification amount message based on owedAmount
function generateAmountMessage(owedAmount: number): string {
  if (owedAmount < 0) { 
    return `- ${messages.owe.replace("{amount}", formatCurrency(Math.abs(owedAmount)))}`; 
  } else if (owedAmount > 0) { 
    return `- ${messages.getBack.replace("{amount}", formatCurrency(owedAmount))}`;
  } else {
    return `- ${messages.oweNothing}`;
  }
}

// Function to send notification using FCM with retry mechanism
async function sendNotification(userId: string, title: string, body: string, activityId: string, maxRetries = 5) {
  const baseDelay = 1000; // Initial delay in milliseconds
  let attempt = 0;

  while (attempt <= maxRetries) {
    try {
      const userDoc = await db.collection('users').doc(userId).get();

      if (userDoc.exists) {
        const userData = userDoc.data() as UserData;

        if (userData?.device_fcm_token) {
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
          return; // Exit function on success
        } else {
          logger.warn(`No FCM token found for user: ${userId}`);
          return; // Exit if there is no FCM token
        }
      } else {
        logger.warn(`User document does not exist for user: ${userId}`);
        attempt++;
      }
    } catch (error) {
      attempt++;
      logger.error(`Error sending notification (attempt ${attempt}):`, error);

      if (attempt > maxRetries) {
        logger.error(`Max retries reached for user: ${userId}. Notification failed.`);
        break;
      }

      // Calculate exponential backoff delay
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay)); // Wait before retrying
    }
  }
}