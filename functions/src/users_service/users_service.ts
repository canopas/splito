/* eslint-disable */

import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import * as _ from 'lodash';

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// TypeScript interface for balances in the group document
interface Balance {
    id: string;
    balance: number;
  }
  
  // TypeScript interface for user data in the users document
  interface UserData {
    total_owe_amount?: number;
  }
  
  export const onGroupWrite = onDocumentWritten(
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
        if (!_.isEqual(beforeData.balances, afterData.balances)) {

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