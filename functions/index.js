/* eslint-disable */

const { getFirestore } = require('firebase-admin/firestore');
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

const admin = require('firebase-admin');
const logger = require("firebase-functions/logger");

admin.initializeApp();

const db = getFirestore();

exports.updateUserOweAmountOnGroupBalanceChange = onDocumentWritten(
    { document: 'groups/{groupId}' },
    async (event) => {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();

        // Handle edge cases where beforeData or afterData might be null
        if (!beforeData || !afterData) {
            logger.warn('Either beforeData or afterData is null. Exiting function.');
            return;
        }
  
        // Check if balances field changed
        if (beforeData.balances !== afterData.balances) {
            const olderBalances = beforeData.balances || [];
            const updatedBalances = afterData.balances || [];
  
            // Iterate through each member's balance and update their totalOweAmount
            for (const updatedBalance of updatedBalances) {
                const userId = updatedBalance.id;
                const userDocRef = db.collection('users').doc(userId);
                const userDoc = await userDocRef.get();
  
                if (userDoc.exists) {
                    const userData = userDoc.data();

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
    }
);
