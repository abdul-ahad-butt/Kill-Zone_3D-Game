self.addEventListener('install', function (event) {
	self.skipWaiting();
});

self.addEventListener('activate', function (event) {
	event.waitUntil(
		self.registration.unregister().then(function () {
			return self.clients.claim();
		})
	);
});

self.addEventListener('fetch', function (event) {
	// Do nothing, let the browser handle it natively
});
