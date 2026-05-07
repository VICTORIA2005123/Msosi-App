importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBOl9wwSTUK7OVZDotozKFJ-ZOCY4wuloo',
  appId: '1:2488750274:web:6083b72e2d68a1f53f6b5b',
  messagingSenderId: '2488750274',
  projectId: 'msosi-app-f9114',
  authDomain: 'msosi-app-f9114.firebaseapp.com',
  storageBucket: 'msosi-app-f9114.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
