/*
 * coi-serviceworker v0.1.7 - (minimal edition for Kill-Zone 3D Game)
 * Cross-Origin Isolation Service Worker
 *
 * Injects Cross-Origin-Opener-Policy: same-origin and
 * Cross-Origin-Embedder-Policy: require-corp headers so that
 * SharedArrayBuffer (required by Godot) works on GitHub Pages.
 *
 * Source: https://github.com/gzuidhof/coi-serviceworker
 */

// Install: skip waiting and activate immediately
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) =>
  event.waitUntil(self.clients.claim())
);

// Fetch: add COOP/COEP headers to every response
self.addEventListener("fetch", function (event) {
  if (event.request.cache === "only-if-cached" && event.request.mode !== "same-origin") {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(function (response) {
        // Don't modify opaque (cross-origin no-cors) responses
        if (response.type === "opaque" || response.type === "opaqueredirect") {
          return response;
        }

        const newHeaders = new Headers(response.headers);
        newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
        newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
        newHeaders.set("Cross-Origin-Resource-Policy", "cross-origin");

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders,
        });
      })
      .catch(function (e) {
        console.error(e);
      })
  );
});
