/* eslint-disable */

import { getFirestore, Firestore } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const db: Firestore = getFirestore();
const notificationTitle = `Splito`;

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
          const owedAmount = calculateOwedAmount(expenseData, userId);
          const message = generateNotificationMessage(owedAmount);
          const body = `${expenseData.name} (${formatCurrency(expenseData.amount)})\n${message}`;
          
          await sendNotification(userId, notificationTitle, body);
        }
      }

      logger.info(`Expense created notification sent successfully. Expense Data: ${JSON.stringify(expenseData)}`);
    } catch (error) {
      logger.error('Error in onExpenseCreated function:', error);
    }
  }
);

// Cloud Function to handle expense updates and notify users
exports.onExpenseUpdated = onDocumentUpdated(
  { document: 'groups/{groupId}/expenses/{expenseId}' },
  async (event) => {
    try {
      const oldExpenseData = event.data?.before?.data(); // Data before the update
      const newExpenseData = event.data?.after?.data();  // Data after the update

      if (!oldExpenseData || !newExpenseData) {
        logger.warn('No data found for the updated expense.');
        return;
      }

      const splitToUsers = newExpenseData.split_to || [];
      const addedBy = newExpenseData.added_by;

      // Notify users who remain in the split list if their owed amount has changed
      for (const userId of splitToUsers) {
        if (userId !== addedBy) {
          const oldOwedAmount = calculateOwedAmount(oldExpenseData, userId);
          const newOwedAmount = calculateOwedAmount(newExpenseData, userId);

          // Notify only if the user's owed or payback amount has changed
          if (oldOwedAmount !== newOwedAmount) {
            const message = generateNotificationMessage(newOwedAmount);
            const body = `Expense updated: ${newExpenseData.name} (${formatCurrency(newExpenseData.amount)})\n${message}`;

            await sendNotification(userId, notificationTitle, body);
          }
        }
      }

      // Notify users who were removed from the expense split list
      const oldSplitUsers = oldExpenseData.split_to || [];
      for (const userId of oldSplitUsers) {
        if (!splitToUsers.includes(userId) && userId !== addedBy) {
          const body = `Expense updated: ${oldExpenseData.name} (${formatCurrency(oldExpenseData.amount)})\n- You do not owe anything`;

          await sendNotification(userId, notificationTitle, body);
        }
      }

      // Notify users added as payers but not in the split list
      const newPayers = newExpenseData.paid_by || {};
      for (const userId of Object.keys(newPayers)) {
        if (!splitToUsers.includes(userId) && userId !== addedBy) {
          const owedAmount = calculateOwedAmount(newExpenseData, userId);
          const message = generateNotificationMessage(owedAmount);
          const body = `Expense updated: ${newExpenseData.name} (${formatCurrency(newExpenseData.amount)})\n${message}`;

          await sendNotification(userId, notificationTitle, body);
        }
      }

      // Notify payers removed from the expense
      const oldPayers = oldExpenseData.paid_by || {};
      for (const userId of Object.keys(oldPayers)) {
        if (!Object.keys(newPayers).includes(userId) && !splitToUsers.includes(userId) && userId !== addedBy) {
          const body = `Expense updated: ${oldExpenseData.name} (${formatCurrency(oldExpenseData.amount)})\n- You do not owe anything`;

          await sendNotification(userId, notificationTitle, body);
        }
      }

      logger.info(`Expense updated notification sent successfully. Expense Data: ${JSON.stringify(newExpenseData)}`);
    } catch (error) {
      logger.error('Error in onExpenseUpdated function:', error);
    }
  }
);

// Cloud Function to handle expense deletion and notify users
exports.onExpenseDeleted = onDocumentDeleted(
  { document: 'groups/{groupId}/expenses/{expenseId}' },
  async (event) => {
    try {
      const expenseData = event.data?.data();
      if (!expenseData) {
        logger.warn('No data found for the deleted expense.');
        return;
      }

      const splitToUsers = expenseData.split_to || [];
      const paidByUsers = expenseData.paid_by || {};
      const addedBy = expenseData.added_by;

      // Notify users who were in the split list
      for (const userId of splitToUsers) {
        if (userId !== addedBy) {
          const owedAmount = calculateOwedAmount(expenseData, userId);
          const message = generateNotificationMessage(owedAmount)
          const body = `Expense deleted: ${expenseData.name} (${formatCurrency(expenseData.amount)})\n${message}`;

          await sendNotification(userId, notificationTitle, body);
        }
      }

      // Notify users who paid but are not in the split list
      for (const userId of Object.keys(paidByUsers)) {
        if (!splitToUsers.includes(userId) && userId !== addedBy) {
          const paidAmount = paidByUsers[userId] || 0;
          let message = generateNotificationMessage(paidAmount)
          const body = `Expense deleted: ${expenseData.name} (${formatCurrency(expenseData.amount)})\n${message}`;

          await sendNotification(userId, notificationTitle, body);
        }
      }

      logger.info(`Expense deletion notification sent successfully. Expense Data: ${JSON.stringify(expenseData)}`);
    } catch (error) {
      logger.error('Error in onExpenseDeleted function:', error);
    }
  }
);

// Helper function to generate notification message based on owedAmount
function generateNotificationMessage(owedAmount: number): string {
  if (owedAmount < 0) { 
    return `- You owe ${formatCurrency(Math.abs(owedAmount))}`; 
  } else if (owedAmount > 0) { 
    return `- You get back ${formatCurrency(owedAmount)}`;
  } else {
    return `- You owe ${formatCurrency(0)}`;
  }
}

// Helper function to format currency
function formatCurrency(amount: number): string {
  const formatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' });
  return formatter.format(amount);
}

// Function to calculate the owed or payback amount for a member
function calculateOwedAmount(expenseData: admin.firestore.DocumentData, memberId: string) {
  const splitTo = expenseData.split_to as string[];
  const splitAmount = getTotalSplitAmountOf(expenseData, memberId);
  const paidAmount = expenseData.paid_by[memberId] || 0;

  if (expenseData.paid_by.hasOwnProperty(memberId)) {
    return paidAmount - (splitTo.includes(memberId) ? splitAmount : 0);  // If the member has paid, calculate based on paid and split amounts
  } else if (splitTo.includes(memberId)) {
    return -splitAmount;  // If the member is part of the split group but hasn’t paid anything, they owe the split amount
  } else {
    return paidAmount;  // If the member isn’t part of the split group or the payment list, return 0
  }
}

// Function to calculate the total split amount for a member
function getTotalSplitAmountOf(expenseData: admin.firestore.DocumentData, member: string): number {
  const splitTo = expenseData.split_to as string[];
  if (!splitTo.includes(member)) return 0;

  const splitType = expenseData.split_type as 'equally' | 'fixedAmount' | 'percentage' | 'shares';
  const splitData = expenseData.split_data as Record<string, number>;
  const amount = expenseData.amount as number;

  switch (splitType) {
    case 'equally':
      return amount / splitTo.length;

    case 'fixedAmount':
      return (splitData)[member] || 0;

    case 'percentage': {
      const totalPercentage = Object.values(splitData)
        .reduce((sum, val) => sum + (val as number), 0);
      if (totalPercentage === 0) return 0; // Avoid division by zero
      return (amount * ((splitData)[member] || 0)) / totalPercentage;
    }

    case 'shares': {
      const totalShares = Object.values(splitData)
        .reduce((sum, val) => sum + (val as number), 0); 
      if (totalShares === 0) return 0; // Avoid division by zero
      return (amount * ((splitData)[member] || 0)) / totalShares;
    }

    default:
      return 0;
  }
}

// Function to send notification using FCM
async function sendNotification(userId: string, title: string, body: string) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userDoc.exists && userData?.deviceFcmToken) {
      const fcmToken = userData?.deviceFcmToken;

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
