import { USER_SESSION_READY } from '../constants/appEvents';
import DashboardAudioNotificationHelper from './AudioAlerts/DashboardAudioNotificationHelper';
import { emitter } from 'shared/helpers/mitt';

export const initializeAudioAlerts = user => {
  const { ui_settings: uiSettings } = user || {};
  const {
    always_play_audio_alert: alwaysPlayAudioAlert,
    enable_audio_alerts: audioAlertType,
    alert_if_unread_assigned_conversation_exist: alertIfUnreadConversationExist,
    notification_tone: audioAlertTone,
    // UI Settings can be undefined initially as we don't send the
    // entire payload for the user during the signup process.
  } = uiSettings || {};

  DashboardAudioNotificationHelper.set({
    currentUser: user,
    audioAlertType: audioAlertType || 'none',
    audioAlertTone: audioAlertTone || 'ding',
    alwaysPlayAudioAlert: alwaysPlayAudioAlert || false,
    alertIfUnreadConversationExist: alertIfUnreadConversationExist || false,
  });
};

export const initializeUserSessionEvents = () => {
  emitter.on(USER_SESSION_READY, ({ user }) => {
    initializeAudioAlerts(user);
  });
};
