/* eslint-disable */

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import { onGroupWrite } from './users_service/users_service'; 
import { onActivityCreate } from './notifications_service/notifications_service';

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  try {
    admin.initializeApp();
    logger.info('Firebase app initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize Firebase app:', error);
    throw error;  // Re-throw to prevent function execution with uninitialized app
  }
} else {
  logger.debug('Firebase app already initialized');
}

exports.onGroupWrite = onGroupWrite;
exports.onActivityCreate = onActivityCreate;
