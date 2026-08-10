self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const url = event.request.url;
  
  if (url.includes('/dtv/current-service')) {
    event.respondWith(new Promise((resolve, reject) => {
      self.clients.matchAll().then(clients => {
        if (clients.length === 0) {
          resolve(new Response('No active Dart clients', { status: 503 }));
          return;
        }

        // Send to the first available client
        const client = clients[0];
        const channel = new MessageChannel();
        
        channel.port1.onmessage = (msgEvent) => {
          const res = msgEvent.data;
          resolve(new Response(res.body, { 
            status: res.status, 
            headers: res.headers 
          }));
        };

        client.postMessage({
          type: 'CCWS_REQUEST',
          url: event.request.url,
          method: event.request.method
        }, [channel.port2]);
        
        // Timeout in case Dart doesn't respond quickly enough
        setTimeout(() => {
          resolve(new Response('Gateway Timeout from Dart', { status: 504 }));
        }, 5000);
      }).catch(err => {
        resolve(new Response('Internal Error: ' + err, { status: 500 }));
      });
    }));
  }
});
