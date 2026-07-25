/**
 * coi-serviceworker.js — Cross-Origin Isolation for GitHub Pages
 *
 * This service worker intercepts every fetch request and injects:
 *   Cross-Origin-Opener-Policy: same-origin
 *   Cross-Origin-Embedder-Policy: require-corp
 *   Cross-Origin-Resource-Policy: cross-origin
 *
 * These headers make window.crossOriginIsolated === true, which is required
 * by Godot 4 / Emscripten for SharedArrayBuffer support.
 *
 * GitHub Pages does NOT serve these headers natively, so we use this SW.
 */

"use strict";

self.addEventListener("install", function (event) {
	// Activate immediately, don't wait for old SW to die
	event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", function (event) {
	// Take control of all pages immediately
	event.waitUntil(self.clients.claim());
});

// Handle SKIP_WAITING messages from the page
self.addEventListener("message", function (event) {
	if (event.data && event.data.type === "SKIP_WAITING") {
		self.skipWaiting();
	}
});

self.addEventListener("fetch", function (event) {
	var request = event.request;

	// Don't intercept non-GET requests (POST, etc.)
	if (request.method !== "GET") {
		return;
	}

	// Don't intercept if only-if-cached with wrong mode (causes TypeError)
	if (request.cache === "only-if-cached" && request.mode !== "same-origin") {
		return;
	}

	event.respondWith(
		fetch(request)
			.then(function (response) {
				// Only modify responses we can actually touch
				if (
					response.type === "opaque" ||
					response.type === "opaqueredirect" ||
					response.status === 0
				) {
					return response;
				}

				var headers = new Headers(response.headers);
				headers.set("Cross-Origin-Opener-Policy", "same-origin");
				headers.set("Cross-Origin-Embedder-Policy", "require-corp");
				headers.set("Cross-Origin-Resource-Policy", "cross-origin");

				return new Response(response.body, {
					status: response.status,
					statusText: response.statusText,
					headers: headers,
				});
			})
			.catch(function (err) {
				// Network failure — return a minimal error response
				console.error("[COI-SW] Fetch failed:", request.url, err);
				return new Response("Network error: " + err.message, {
					status: 503,
					statusText: "Service Unavailable",
				});
			})
	);
});
