/* eslint-disable */

import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

const db: Firestore = getFirestore();

// TypeScript interface for balances in the group document
interface Balance {
  id: string;
  balance: number;
}

// TypeScript interface for user data in the users document
interface UserData {
  total_owe_amount?: number;
}

exports.onGroupWrite = onDocumentWritten(
  { document: 'groups/{groupId}' },
  async (event) => {
    try {
      // Typing event data as DocumentSnapshot
      const beforeData = event.data?.before?.data() as { balances: Balance[] } | undefined;
      const afterData = event.data?.after?.data() as { balances: Balance[] } | undefined;

      // Handle edge cases where beforeData or afterData might be null
      if (!beforeData || !afterData) {
        logger.warn('Either beforeData or afterData is null. Exiting function.');
        return;
      }

      // Check if balances field changed
      if (beforeData.balances != afterData.balances) {
        const olderBalances = beforeData.balances || [];
        const updatedBalances = afterData.balances || [];

        // Iterate through each member's balance and update their totalOweAmount
        for (const updatedBalance of updatedBalances) {
          const userId = updatedBalance.id;
          const userDocRef = db.collection('users').doc(userId);
          const userDoc = await userDocRef.get();

          if (userDoc.exists) {
            const userData = userDoc.data() as UserData;

            const oldBalance = olderBalances.find((balance) => balance.id === userId);
            
            let diffAmount = 0;

            if (oldBalance) {
              // Calculate difference between old and new balance
              diffAmount = updatedBalance.balance - oldBalance.balance;
            } else {
              // No old balance means it's a new entry, just use the new balance
              diffAmount = updatedBalance.balance;
            }

            const newTotalOweAmount = (userData.total_owe_amount || 0) + diffAmount;
            logger.info(`Updating user ${userId} with new totalOweAmount:`, newTotalOweAmount);

            // Update user's totalOweAmount field
            await userDocRef.update({
              total_owe_amount: newTotalOweAmount,
            });

            logger.info(`Successfully updated user ${userId}'s totalOweAmount.`);
          } else {
            logger.warn(`User document does not exist for userId: ${userId}`);
          }
        }
      } else {
        logger.info('No change in balances field detected.');
      }
    } catch (error) {
      logger.error('Error updating user owe amounts:', error);
    }
  }
);


// Function to send notification using FCM
async function sendNotification(userId: string, title: string, body: string) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (userDoc.exists && userDoc.data()?.fcmToken) {
      const fcmToken = userDoc.data()?.fcmToken;

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

// Cloud Function to handle new expense creation and notify users
exports.onExpenseCreated = onDocumentCreated(
  { document: 'expenses/{expenseId}' },
  async (event) => {
    try {
      const expenseData = event.data?.data();
      if (!expenseData) {
        logger.warn('No data found for the newly created expense.');
        return;
      }

      // Extract users who share the expense and the user who added it
      const splitToUsers = expenseData.splitTo || [];
      const addedBy = expenseData.addedBy;

      // Notify all users in splitTo except the one who added the expense
      for (const userId of splitToUsers) {
        if (userId !== addedBy) {
          await sendNotification(
            userId,
            `New Expense Added`,
            `${expenseData.name} of ₹${expenseData.amount.toFixed(2)} has been added.`
          );
        }
      }

      logger.info('Expense created notification sent successfully.');
    } catch (error) {
      logger.error('Error in onExpenseCreated function:', error);
    }
  }
);