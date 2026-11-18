// Firebase Cloud Messaging service worker for the web build. FCM needs it to
// show pushes while the app tab is in the background. Only the public web
// config is here (same values as lib/firebase_options.dart); the VAPID key is
// passed at build time (--dart-define=FCM_WEB_VAPID_KEY=...).
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB2v3Z6l9dJ9bLWrzk1D8DiVISBN2fck3k',
  appId: '1:1014327278289:web:5febadb90951ab938723f0',
  messagingSenderId: '1014327278289',
  projectId: 'ai-devops-command-center',
  storageBucket: 'ai-devops-command-center.firebasestorage.app',
});

// Clicking a push focuses an open app tab, or opens the app if none is open.
// Registered before firebase.messaging() so it runs before the SDK's own
// click handler (which only acts when the message has a link).
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const payload = (event.notification.data && event.notification.data.FCM_MSG) || {};
  const data = payload.data || {};
  const appUrl = new URL('./', self.registration.scope).href;
  event.stopImmediatePropagation();
  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    const tab = windows.find((w) => w.url.startsWith(appUrl));
    const client = tab ? await tab.focus() : await clients.openWindow(appUrl);
    // The app can use this to open the incident; ignored if it does not listen.
    if (client) client.postMessage({ type: 'push-click', incident_id: data.incident_id || null, notification_id: data.notification_id || null });
  })());
});

// Messages with a "notification" part are shown by FCM itself.
firebase.messaging();
