/* Ri-work 알림 수신기 (서비스워커)
   앱이 꺼져 있어도 이 파일이 깨어나 알림을 띄운다.
   회사 PC의 웹푸시_발송.py 가 보낸 내용을 받는다. */
const VER = 'riwork-sw-1';

self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('push', event => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data && event.data.text() }; }
  const title = d.title || '리플래시 work';
  const opts = {
    body: d.body || '',
    icon: d.icon || 'icon192.png',
    badge: 'icon192.png',
    tag: d.tag || 'riwork',          // 같은 tag 는 덮어쓰기 — 알림이 쌓이지 않게
    renotify: true,
    requireInteraction: !!d.keep,    // 중요한 알림은 손으로 닫을 때까지 유지
    data: { url: d.url || './', act: d.act || null }
  };
  if (d.actions) opts.actions = d.actions;
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const data = event.notification.data || {};
  // 버튼을 눌렀으면 그 버튼의 주소로, 아니면 앱을 연다
  let url = data.url || './';
  if (event.action && event.notification.actions) {
    const a = event.notification.actions.find(x => x.action === event.action);
    if (a && a.url) url = a.url;
  }
  event.waitUntil((async () => {
    const list = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of list) {                      // 이미 열려 있으면 그 창을 앞으로
      if ('focus' in c) { try { await c.focus(); if (data.act) c.postMessage({ act: data.act }); return; } catch (e) {} }
    }
    if (self.clients.openWindow) await self.clients.openWindow(url);
  })());
});
