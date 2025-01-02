/* eslint-disable */

import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import * as _ from 'lodash';

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  try {
    admin.initializeApp();
    logger.info('Firebase app initialized in users_service');
  } catch (error) {
    logger.error('Failed to initialize Firebase app in users_service:', error);
    throw error;  // Prevent further function execution
  }
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
      // Extract 'before' and 'after' data from the event
      const beforeData = event.data?.before?.data() as { balances: Balance[], is_active: boolean } | undefined;
      const afterData = event.data?.after?.data() as { balances: Balance[], is_active: boolean } | undefined;
  
      // Check if either 'before' or 'after' data is null and exit early if so
      if (!beforeData || !afterData) {
        logger.warn('Either beforeData or afterData is null. Exiting function.');
        return;
      }

      // Initialize a Firestore batch to group all write operations
      const batch = db.batch();

      // Helper function to process balances and update user totals
      const processBalances = async (balances: Balance[], multiplier: number) => {
        for (const { id, balance } of balances) {

          // Get the Firestore document reference for the user
          const userDocRef = db.collection('users').doc(id);
          const userDoc = await userDocRef.get();

          // Skip if the user document does not exist
          if (!userDoc.exists) {
            logger.warn(`User document does not exist for userId: ${id}`);
            continue;
          }
          
          // Retrieve user data and calculate the updated total balance
          const userData = userDoc.data() as UserData;
          const updatedTotal = (userData.total_owe_amount || 0) + multiplier * balance;

          // Add the update to the batch
          batch.update(userDocRef, { total_owe_amount: updatedTotal });
        }
      };

      // Determine the type of change (activation, deactivation, or balance update)
      const isGroupActivated = !beforeData?.is_active && afterData?.is_active;
      const isGroupDeactivated = beforeData?.is_active && !afterData?.is_active;
      const balancesChanged = beforeData?.balances && afterData?.balances && !_.isEqual(beforeData.balances, afterData.balances);

      if (isGroupActivated) {
        logger.info('Group activated. Adding balances to user totals.');
        await processBalances(afterData!.balances || [], 1);
      } else if (isGroupDeactivated) {
        logger.info('Group deactivated. Removing balances from user totals.');
        await processBalances(beforeData!.balances || [], -1);
      } else if (balancesChanged && afterData?.is_active) {
        logger.info('Balances changed. Updating user totals.');

        // Calculate the difference between new and old balances for each user
        const balanceDiffs = afterData.balances.map(({ id, balance }) => {
          const oldBalance = beforeData.balances.find((b) => b.id === id)?.balance || 0;
          return { id, balance: balance - oldBalance };
        });

        // Process the calculated differences
        await processBalances(balanceDiffs, 1);
      }
  
      // Commit all updates in a single batch operation
      await batch.commit();
      logger.info('Successfully committed all updates.');

    } catch (error) {
      logger.error('Error updating user owe amounts:', error);
    }
  }
);