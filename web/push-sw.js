// Web Push service worker for the parking management PWA.
//
// `push-dispatch` sends {title, body, data} as JSON; the data payload is the
// same one the in-app notification carries, so a tap can deep-link with
// `notificationclick` into the matching screen.

self.addEventListener('push', (event) => {
  let payload = { title: 'Parking', body: '', data: {} };
  try {
    payload = { ...payload, ...(event.data ? event.data.json() : {}) };
  } catch (_) {
    payload.body = event.data ? event.data.text() : '';
  }
  event.waitUntil(
    self.registration.showNotification(payload.title || 'Parking', {
      body: payload.body || '',
      data: payload.data || {},
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const plate = typeof data.plate === 'string' ? data.plate : '';
  let route = '/';
  if (data.type === 'shift_closed') route = '/shift';
  else if (
    data.type === 'monthly_pass_expiring' ||
    data.type === 'monthly_pass_renewed'
  ) {
    route = '/monthly-passes';
  } else if (['check_in', 'check_out', 'overstay'].includes(data.type)) {
    route = plate ? `/history?plate=${encodeURIComponent(plate)}` : '/history';
  }
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ('focus' in client) {
          client.navigate(route);
          return client.focus();
        }
      }
      return self.clients.openWindow(route);
    }),
  );
});
