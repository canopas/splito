/* eslint-disable */

import * as admin from 'firebase-admin';
import { onGroupWrite } from './users_service/users_service'; 
import * as logger from 'firebase-functions/logger'; // Import logger
import { onActivityCreate } from './notifications_service/notifications_service';

logger.info('Initializing Firebase app...');

// Initialize Firebase app if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

logger.info('Firebase app initialized successfully.');

exports.onGroupWrite = onGroupWrite;
exports.onActivityCreate = onActivityCreate;
