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

      logger.info(`Expense created notification sent successfully Expense Data: ${expenseData}`);
    } catch (error) {
      logger.error('Error in onExpenseCreated function:', error);
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

  const splitType = expenseData.split_type;

  switch (splitType) {
    case 'equally':
      return expenseData.amount / expenseData.split_to.length;

    case 'fixedAmount':
      return (expenseData.split_data as Record<string, number>)[member] || 0;

    case 'percentage': {
      const totalPercentage = Object.values(expenseData.split_data as Record<string, number>)
        .reduce((sum, val) => sum + (val as number), 0);
      return (expenseData.amount * ((expenseData.split_data as Record<string, number>)[member] || 0)) / totalPercentage;
    }

    case 'shares': {
      const totalShares = Object.values(expenseData.split_data as Record<string, number>)
        .reduce((sum, val) => sum + (val as number), 0); 
      return (expenseData.amount * ((expenseData.split_data as Record<string, number>)[member] || 0)) / totalShares;
    }

    default:
      return 0;
  }
}

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