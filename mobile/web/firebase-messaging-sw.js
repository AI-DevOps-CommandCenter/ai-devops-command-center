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

// Messages with a "notification" part are shown by FCM itself.
firebase.messaging();
