/* eslint-disable */

import { getFirestore, Firestore } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
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
          const owedAmount = calculateOwedAmount(expenseData, userId);

          let message = '';
          if (owedAmount < 0) { // Negative value means the user owes money
            message = `- You owe ₹${Math.abs(owedAmount).toFixed(2)}`;
          } else if (owedAmount > 0) { // Positive value means the user gets money back
            message = `- You get back ₹${owedAmount.toFixed(2)}`;
          } else {
            message = `- You owe ₹0.00`;
          }

          const title = `Splito`;
          const body = `${expenseData.name} (₹${expenseData.amount.toFixed(2)})\n${message}`;
      
          await sendNotification(userId, title, body);
        }
      }

      logger.info(`Expense created notification sent successfully. Expense Data: ${JSON.stringify(expenseData)}`);
    } catch (error) {
      logger.error('Error in onExpenseCreated function:', error);
    }
  }
);

exports.onExpenseUpdated = onDocumentUpdated(
  { document: 'groups/{groupId}/expenses/{expenseId}' },
  async (event) => {
    try {
      const oldExpenseData = event.data?.before?.data(); // The data before the update
      const newExpenseData = event.data?.after?.data();  // The data after the update

      if (!oldExpenseData || !newExpenseData) {
        logger.warn('No data found for the updated expense.');
        return;
      }

      const splitToUsers = newExpenseData.split_to || [];
      const addedBy = newExpenseData.added_by;

      // Notify users who remain in the split list
      for (const userId of splitToUsers) {
        if (userId !== addedBy) {
          const oldOwedAmount = calculateOwedAmount(oldExpenseData, userId);
          const newOwedAmount = calculateOwedAmount(newExpenseData, userId);

          // Notify only if the user's owed or payback amount has changed
          if (oldOwedAmount !== newOwedAmount) {
            let message = '';
            if (newOwedAmount < 0) {
              message = `- You owe ₹${Math.abs(newOwedAmount).toFixed(2)}`;
            } else if (newOwedAmount > 0) {
              message = `- You get back ₹${newOwedAmount.toFixed(2)}`;
            } else {
              message = `- You owe ₹0.00`;
            }

            const title = `Splito`;
            const body = `Expense updated: ${newExpenseData.name} (₹${newExpenseData.amount.toFixed(2)})\n${message}`;

            await sendNotification(userId, title, body);
          }
        }
      }

      // Notify users who were removed from the expense split list
      const oldSplitUsers = oldExpenseData.split_to || [];
      for (const userId of oldSplitUsers) {
        if (!splitToUsers.includes(userId) && userId !== addedBy) {
          const title = `Splito`;
          const body = `Expense updated: ${oldExpenseData.name} (₹${oldExpenseData.amount.toFixed(2)})\n- You do not owe anything`;

          await sendNotification(userId, title, body);
        }
      }

      // Notify users added as payers but not in the split list
      const newPayers = newExpenseData.paid_by || {};
      for (const userId of Object.keys(newPayers)) {
        if (!splitToUsers.includes(userId) && userId !== addedBy) {
          // Calculate how much they get back based on the new expense data
          const owedAmount = calculateOwedAmount(newExpenseData, userId);

          let message = '';
          if (owedAmount > 0) {
            message = `- You get back ₹${owedAmount.toFixed(2)}`;
          } else {
            message = `- You owe ₹0.00`;
          }

          const title = `Splito`;
          const body = `Expense updated: ${newExpenseData.name} (₹${newExpenseData.amount.toFixed(2)})\n${message}`;
          await sendNotification(userId, title, body);
        }
      }

      // Notify payers removed from the expense
      const oldPayers = oldExpenseData.paid_by || {};
      for (const userId of Object.keys(oldPayers)) {
        // Only send notification if the user is not in the new payers list and is also not in the split list
        if (!Object.keys(newPayers).includes(userId) && !splitToUsers.includes(userId) && userId !== addedBy) {
          const title = `Splito`;
          const body = `Expense updated: ${oldExpenseData.name} (₹${oldExpenseData.amount.toFixed(2)})\n- You do not owe anything`;

          await sendNotification(userId, title, body);
        }
      }

      logger.info(`Expense updated notification sent successfully. Expense Data: ${JSON.stringify(newExpenseData)}`);
    } catch (error) {
      logger.error('Error in onExpenseUpdated function:', error);
    }
  }
);

// Function to calculate the owed or payback amount for a member
function calculateOwedAmount(expenseData: admin.firestore.DocumentData, memberId: string) {
  // Get the total split amount for the member
  const splitAmount = getTotalSplitAmountOf(expenseData, memberId);

  // Get the amount paid by the member
  const paidAmount = expenseData.paid_by[memberId] || 0;

  // If the member has paid, calculate based on paid and split amounts
  if (expenseData.paid_by.hasOwnProperty(memberId)) {
    return paidAmount - (expenseData.split_to.includes(memberId) ? splitAmount : 0);
  }
  // If the member is part of the split group but hasn’t paid anything, they owe the split amount
  else if (expenseData.split_to.includes(memberId)) {
    return -splitAmount;
  }
  // If the member isn’t part of the split group or the payment list, return 0
  return paidAmount;
}

// Function to calculate the total split amount for a member
function getTotalSplitAmountOf(expenseData: admin.firestore.DocumentData, member: string): number {
  if (!expenseData.split_to.includes(member)) return 0;

  const splitType = expenseData.split_type as 'equally' | 'fixedAmount' | 'percentage' | 'shares';
  const splitData = expenseData.split_data as Record<string, number>;

  switch (splitType) {
    case 'equally':
      return expenseData.amount / expenseData.split_to.length;

    case 'fixedAmount':
      return (splitData)[member] || 0;

    case 'percentage': {
      const totalPercentage = Object.values(splitData)
        .reduce((sum, val) => sum + (val as number), 0);
      if (totalPercentage === 0) return 0; // Avoid division by zero
      return (expenseData.amount * ((splitData)[member] || 0)) / totalPercentage;
    }

    case 'shares': {
      const totalShares = Object.values(splitData)
        .reduce((sum, val) => sum + (val as number), 0); 
      if (totalShares === 0) return 0; // Avoid division by zero
      return (expenseData.amount * ((splitData)[member] || 0)) / totalShares;
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

    if (userDoc.exists && userData?.deviceFcmToken) { // Adjusted to use deviceFcmToken
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
