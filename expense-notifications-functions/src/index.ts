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

// Cloud Function to handle add transaction and notify users
exports.onTransactionCreated = onDocumentCreated(
  { document: 'groups/{groupId}/transactions/{transactionId}' },
  async (event) => {
    try {
      const transactionData = event.data?.data();
      if (!transactionData) {
        logger.warn('No data found for the newly created transaction.');
        return;
      }

      const payerName = await getUserDisplayName(transactionData.payer_id);
      const receiverName = await getUserDisplayName(transactionData.receiver_id);

      let receiverMessage;
      let payerMessage;
      if (transactionData.added_by && transactionData.added_by !== transactionData.receiver_id && transactionData.added_by !== transactionData.payer_id) {
        receiverMessage = `${payerName} paid you ${formatCurrency(transactionData.amount)}`;  // Notify the receiver that the payer has made a payment
        payerMessage = `You paid ${receiverName} ${formatCurrency(transactionData.amount)}`;  // Notify the payer that the someone has made a payment
      } else {
        receiverMessage = `${payerName} paid you ${formatCurrency(transactionData.amount)}`; // Notify the receiver that the payer has made a payment
      }

      await sendNotification(transactionData.receiver_id, notificationTitle, receiverMessage);
      if (payerMessage) {
        await sendNotification(transactionData.payer_id, notificationTitle, payerMessage);
      }

      logger.info(`Transaction created notification sent successfully. Transaction Data: ${JSON.stringify(transactionData)}`);
    } catch (error) {
      logger.error('Error in onTransactionCreated function:', error);
    }
  }
);

// Cloud Function to handle update transaction and notify users
exports.onTransactionUpdated = onDocumentUpdated(
  { document: 'groups/{groupId}/transactions/{transactionId}' },
  async (event) => {
    try {
      const oldTransactionData = event.data?.before.data(); // Data before the update
      const newTransactionData = event.data?.after.data(); // Data after the update

      if (!oldTransactionData || !newTransactionData) {
        logger.warn('No data found for the updated transaction.');
        return;
      }

      // Only notify if the amount has changed
      if (oldTransactionData !== newTransactionData) {
        const payerName = await getUserDisplayName(newTransactionData.payer_id);
        const receiverName = await getUserDisplayName(newTransactionData.receiver_id);

        let receiverMessage;
        let payerMessage;
        if (newTransactionData.updated_by && newTransactionData.updated_by !== newTransactionData.receiver_id && newTransactionData.updated_by !== newTransactionData.payer_id) {
          receiverMessage = `Payment updated: ${payerName} paid you ${formatCurrency(newTransactionData.amount)}`;  // Notify the receiver that the payer has made a payment
          payerMessage = `Payment updated: you paid ${receiverName} ${formatCurrency(newTransactionData.amount)}`;  // Notify the payer that the someone has made a payment
        } else if (newTransactionData.updated_by && newTransactionData.updated_by == newTransactionData.receiver_id) {
          payerMessage = `You paid ${receiverName} ${formatCurrency(newTransactionData.amount)}`;  // Notify the payer that the someone has made a payment
        } else if (newTransactionData.updated_by && newTransactionData.updated_by == newTransactionData.payer_id) {
          receiverMessage = `${payerName} paid you ${formatCurrency(newTransactionData.amount)}`;  // Notify the receiver that the payer has made a payment
        }

        // Send notifications
        if (receiverMessage) {
          await sendNotification(newTransactionData.receiver_id, notificationTitle, receiverMessage);
        }
        if (payerMessage) {
          await sendNotification(newTransactionData.payer_id, notificationTitle, payerMessage);
        }

        logger.info(`Transaction updated notification sent successfully. Updated Data: ${JSON.stringify(newTransactionData)}`);
      }
    } catch (error) {
      logger.error('Error in onTransactionUpdated function:', error);
    }
  }
);

// Cloud Function to handle delete transaction and notify users
exports.onTransactionDeleted = onDocumentDeleted(
  { document: 'groups/{groupId}/transactions/{transactionId}' },
  async (event) => {
    try {
      const deletedTransactionData = event.data?.data(); // Data of the deleted transaction

      if (!deletedTransactionData) {
        logger.warn('No data found for the deleted transaction.');
        return;
      }

      const payerName = await getUserDisplayName(deletedTransactionData.payer_id);
      const receiverName = await getUserDisplayName(deletedTransactionData.receiver_id);

      const receiverMessage = `${payerName} deleted the payment of ${formatCurrency(deletedTransactionData.amount)} that was made to you.`; // Notify the receiver about the deletion
      const payerMessage = `You deleted the payment of ${formatCurrency(deletedTransactionData.amount)} that was made to ${receiverName}.`; // Notify the payer about the deletion

      // Send notifications
      await sendNotification(deletedTransactionData.receiver_id, notificationTitle, receiverMessage);
      await sendNotification(deletedTransactionData.payer_id, notificationTitle, payerMessage);

      logger.info(`Transaction deleted notification sent successfully. Deleted Data: ${JSON.stringify(deletedTransactionData)}`);
    } catch (error) {
      logger.error('Error in onTransactionDeleted function:', error);
    }
  }
);

async function getUserDisplayName(userId: string) {
  if (!userId) {
    console.error('Invalid userId:', userId);
    return 'Unknown';
  }

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData && userData.first_name ? userData.first_name : 'Unknown';
    } else {
      return 'Unknown'; // Return 'Unknown' if the document doesn't exist
    }
  } catch (error) {
    console.error('Error retrieving user name:', error);
    return 'Unknown'; // Return 'Unknown' in case of an error
  }
}

// Cloud Function to handle delete group and notify users
exports.onGroupDeleted = onDocumentDeleted(
  { document: 'groups/{groupId}' },
  async (event) => {
    try {
      const deletedGroupData = event.data?.data(); // Data of the deleted group

      if (!deletedGroupData) {
        logger.warn('No data found for the deleted group.');
        return;
      }

      const groupId = event.params.groupId; // Get the groupId from the event parameters
      const members = deletedGroupData.members; // Get the list of members from the deleted group

      // Construct the notification message
      const message = `The group '${deletedGroupData.name}' has been deleted.`;

      // Send notifications to all group members
      for (const memberId of members) {
        await sendNotification(memberId, notificationTitle, message);
      }

      logger.info(`Group deletion notification sent successfully to members of group ${groupId}.`);
    } catch (error) {
      logger.error('Error in onGroupDeleted function:', error);
    }
  }
);

// Cloud Function to handle member removal from a group and notify users
exports.onMemberRemoved = onDocumentUpdated(
  { document: 'groups/{groupId}' },
  async (event) => {
    try {
      const oldGroupData = event.data?.before.data(); // Data before the update
      const newGroupData = event.data?.after.data(); // Data after the update

      if (!oldGroupData || !newGroupData) {
        logger.warn('No data found for the updated group.');
        return;
      }

      const oldMembers: string[] = oldGroupData.members; // Members before the update
      const newMembers: string[] = newGroupData.members; // Members after the update

      // Check for removed members
      const removedMembers = oldMembers.filter((memberId: string) => !newMembers.includes(memberId));

      // Send notifications to removed members
      for (const memberId of removedMembers) {
        const removerName = await getUserDisplayName(newGroupData.createdBy); // Get the name of the user who removed the member
        const message = `${removerName} removed you from the group “${newGroupData.name}”.`;
        await sendNotification(memberId, notificationTitle, message);
      }

      logger.info(`Member removal notifications sent successfully for group ${event.params.groupId}.`);
    } catch (error) {
      logger.error('Error in onMemberRemoved function:', error);
    }
  }
);
