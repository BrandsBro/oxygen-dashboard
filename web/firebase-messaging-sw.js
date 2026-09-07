importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAqaVbEW8UOMTOMhKvh9-4yDN2JicRFPx4",
  authDomain: "xygen-dashboard.firebaseapp.com",
  projectId: "xygen-dashboard",
  storageBucket: "xygen-dashboard.firebasestorage.app",
  messagingSenderId: "482948449877",
  appId: "1:482948449877:web:1230b460741c188986f6dc"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Background message:', payload);
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  });
});
