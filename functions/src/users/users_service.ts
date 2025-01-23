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
interface GroupMemberBalance {
  id: string;
  balance_by_currency: Record<string, GroupCurrencyBalance>;
}

interface GroupCurrencyBalance {
  balance: number;
}

// TypeScript interface for user data in the users document
interface UserData {
  total_owe_amount?: Record<string, number>; // Stores balances by currency
}
  
export const onGroupWrite = onDocumentWritten(
  { document: 'groups/{groupId}' },
  async (event) => {
    try {
      const DEFAULT_CURRENCY = 'INR';

      // Extract 'before' and 'after' data from the event
      const beforeData = event.data?.before?.data() as { balances: GroupMemberBalance[], is_active: boolean } | undefined;
      const afterData = event.data?.after?.data() as { balances: GroupMemberBalance[], is_active: boolean } | undefined;

      // Initialize a Firestore batch to group all write operations
      const batch = db.batch();

      // Helper function to round currency to 2 decimal places
      const roundCurrency = (amount: number): number => {
        return Number(amount.toFixed(2));
      };

      // Helper function to process balances and update user totals
      const processBalances = async (balances: GroupMemberBalance[], multiplier: number) => {
        if (balances.length === 0) return; // Skip if balances are empty

        // Optimize Firestore reads by batching user document fetches
        const userDocRefs = balances.map(({ id }) => db.collection('users').doc(id));
        const userDocs = [];
        const BATCH_SIZE = 500;
        
        for (let i = 0; i < userDocRefs.length; i += BATCH_SIZE) {
          const batchDocRefs = userDocRefs.slice(i, i + BATCH_SIZE);
          const batchUserDocs = await db.getAll(...batchDocRefs);
          userDocs.push(...batchUserDocs);
        }

        // Process each user document
        userDocs.forEach((userDoc, index) => {
          if (!userDoc.exists) {
            logger.warn(`User document does not exist for userId: ${balances[index].id}`);
            return;
          }

          const userData = userDoc.data() as UserData;
          const updatedTotal = { ...userData.total_owe_amount };

          // Iterate over each currency in the balance_by_currency
          const { balance_by_currency } = balances[index];
          for (const [currency, currencyBalance] of Object.entries(balance_by_currency)) {
            const currencyKey = currency || DEFAULT_CURRENCY;
            const currentBalance = updatedTotal[currencyKey] || 0;
            updatedTotal[currencyKey] = roundCurrency(currentBalance + multiplier * currencyBalance.balance);
          }

          // Ensure at least the default currency is present
          if (!updatedTotal[DEFAULT_CURRENCY]) {
            updatedTotal[DEFAULT_CURRENCY] = 0;
          }

          // Add the update to the batch
          batch.update(userDocRefs[index], { total_owe_amount: updatedTotal });
          logger.info(`Updated total_owe_amount for user ${balances[index].id}:`, updatedTotal);
        });
      };

      // Check if either 'before' or 'after' data is null and exit early if so
      if (!beforeData || !afterData) {
        logger.warn('Either beforeData or afterData is null. Exiting function.');
        return;
      }

      // Handle undefined balances as empty arrays
      const beforeBalances = beforeData?.balances || [];
      const afterBalances = afterData?.balances || [];

      // Determine the type of change (activation, deactivation, or balance update)
      const isGroupActivated = !beforeData?.is_active && afterData?.is_active;
      const isGroupDeactivated = beforeData?.is_active && !afterData?.is_active;
      const balancesChanged = !_.isEqual(beforeBalances, afterBalances);

      if (isGroupActivated) {
        logger.info('Group activated. Adding balances to user totals.');
        await processBalances(afterBalances, 1);
      } else if (isGroupDeactivated) {
        logger.info('Group deactivated. Removing balances from user totals.');
        await processBalances(beforeBalances, -1);
      } else if (balancesChanged) {
        logger.info('Balances changed. Updating user totals.');

        // Calculate the difference between new and old balances for each user
        const balanceDiffs = afterBalances.map(({ id, balance_by_currency }) => {
          const oldBalances = beforeBalances.find((b) => b.id === id)?.balance_by_currency || {};
          const diffs: Record<string, GroupCurrencyBalance> = {};

          for (const currency of new Set([...Object.keys(balance_by_currency), ...Object.keys(oldBalances)])) {
            const afterCurrencyBalance = balance_by_currency[currency]?.balance || 0;
            const beforeCurrencyBalance = oldBalances[currency]?.balance || 0;
            const diff = afterCurrencyBalance - beforeCurrencyBalance;
            diffs[currency] = { balance: roundCurrency(diff) };
          }

          return { id, balance_by_currency: diffs };
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