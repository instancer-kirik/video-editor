const CACHE_NAME = 'video-recorder-v1.0.0';
const STATIC_CACHE_NAME = 'video-recorder-static-v1.0.0';
const DYNAMIC_CACHE_NAME = 'video-recorder-dynamic-v1.0.0';

// Files to cache for offline use
const STATIC_FILES = [
    '/mobile.html',
    '/mobile-app.js',
    '/manifest.json',
    '/icon-192.png',
    '/icon-512.png',
    '/video-editor.wasm',
    // Add other essential files
];

// Files that can be cached dynamically
const DYNAMIC_FILES = [
    '/camera.js',
    '/ui.js',
    '/styles.css'
];

// Install event - cache static files
self.addEventListener('install', (event) => {
    console.log('Service Worker: Installing...');

    event.waitUntil(
        caches.open(STATIC_CACHE_NAME)
            .then((cache) => {
                console.log('Service Worker: Caching static files');
                return cache.addAll(STATIC_FILES.map(file => {
                    return new Request(file, { cache: 'reload' });
                }));
            })
            .then(() => {
                console.log('Service Worker: Static files cached');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('Service Worker: Failed to cache static files', error);
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('Service Worker: Activating...');

    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames.map((cacheName) => {
                        if (cacheName !== STATIC_CACHE_NAME &&
                            cacheName !== DYNAMIC_CACHE_NAME) {
                            console.log('Service Worker: Deleting old cache', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            })
            .then(() => {
                console.log('Service Worker: Activated');
                return self.clients.claim();
            })
    );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
    const request = event.request;
    const url = new URL(request.url);

    // Skip cross-origin requests
    if (url.origin !== self.location.origin) {
        return;
    }

    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }

    // Skip camera/microphone related requests
    if (url.pathname.includes('getUserMedia') ||
        url.pathname.includes('mediaDevices')) {
        return;
    }

    event.respondWith(
        caches.match(request)
            .then((cachedResponse) => {
                // Return cached version if available
                if (cachedResponse) {
                    console.log('Service Worker: Serving from cache', request.url);
                    return cachedResponse;
                }

                // Otherwise fetch from network and cache dynamically
                return fetch(request)
                    .then((networkResponse) => {
                        // Check if response is valid
                        if (!networkResponse ||
                            networkResponse.status !== 200 ||
                            networkResponse.type !== 'basic') {
                            return networkResponse;
                        }

                        // Clone the response as it can only be consumed once
                        const responseToCache = networkResponse.clone();

                        // Cache dynamic files
                        if (DYNAMIC_FILES.some(file => request.url.includes(file))) {
                            caches.open(DYNAMIC_CACHE_NAME)
                                .then((cache) => {
                                    console.log('Service Worker: Caching dynamic file', request.url);
                                    cache.put(request, responseToCache);
                                });
                        }

                        return networkResponse;
                    })
                    .catch((error) => {
                        console.error('Service Worker: Network fetch failed', error);

                        // Return offline fallback for HTML pages
                        if (request.headers.get('accept').includes('text/html')) {
                            return caches.match('/mobile.html');
                        }

                        // Return empty response for other resources
                        return new Response('Offline', {
                            status: 503,
                            statusText: 'Service Unavailable'
                        });
                    });
            })
    );
});

// Background sync for video uploads (when back online)
self.addEventListener('sync', (event) => {
    console.log('Service Worker: Background sync triggered', event.tag);

    if (event.tag === 'upload-video') {
        event.waitUntil(uploadPendingVideos());
    }
});

// Push notifications for recording reminders
self.addEventListener('push', (event) => {
    console.log('Service Worker: Push notification received');

    const options = {
        body: event.data ? event.data.text() : 'Video recording reminder',
        icon: '/icon-192.png',
        badge: '/icon-72.png',
        tag: 'video-reminder',
        requireInteraction: false,
        actions: [
            {
                action: 'record',
                title: 'Start Recording',
                icon: '/icon-record-192.png'
            },
            {
                action: 'dismiss',
                title: 'Dismiss',
                icon: '/icon-close-192.png'
            }
        ]
    };

    event.waitUntil(
        self.registration.showNotification('Video Recorder', options)
    );
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
    console.log('Service Worker: Notification clicked', event.action);

    event.notification.close();

    if (event.action === 'record') {
        // Open app and start recording
        event.waitUntil(
            clients.openWindow('/mobile.html?quick=true')
        );
    } else if (event.action === 'dismiss') {
        // Just close the notification
        return;
    } else {
        // Default action - open the app
        event.waitUntil(
            clients.openWindow('/mobile.html')
        );
    }
});

// Handle message from main app
self.addEventListener('message', (event) => {
    console.log('Service Worker: Message received', event.data);

    if (event.data.type === 'CACHE_VIDEO') {
        // Cache a recorded video for offline access
        cacheVideo(event.data.videoData);
    } else if (event.data.type === 'CLEAR_CACHE') {
        // Clear all caches
        clearAllCaches();
    } else if (event.data.type === 'GET_CACHE_SIZE') {
        // Return cache size information
        getCacheSize().then((size) => {
            event.ports[0].postMessage({ cacheSize: size });
        });
    }
});

// Utility functions
async function uploadPendingVideos() {
    try {
        // Get pending videos from IndexedDB or localStorage
        const pendingVideos = await getPendingVideos();

        for (const video of pendingVideos) {
            try {
                await uploadVideo(video);
                await removePendingVideo(video.id);
                console.log('Service Worker: Video uploaded successfully', video.id);
            } catch (error) {
                console.error('Service Worker: Failed to upload video', video.id, error);
            }
        }
    } catch (error) {
        console.error('Service Worker: Failed to process pending videos', error);
    }
}

async function cacheVideo(videoData) {
    try {
        const cache = await caches.open(DYNAMIC_CACHE_NAME);
        const response = new Response(videoData.blob, {
            headers: {
                'Content-Type': videoData.mimeType,
                'Content-Length': videoData.blob.size
            }
        });

        await cache.put(`/videos/${videoData.id}`, response);
        console.log('Service Worker: Video cached', videoData.id);
    } catch (error) {
        console.error('Service Worker: Failed to cache video', error);
    }
}

async function clearAllCaches() {
    try {
        const cacheNames = await caches.keys();
        await Promise.all(
            cacheNames.map(cacheName => caches.delete(cacheName))
        );
        console.log('Service Worker: All caches cleared');
    } catch (error) {
        console.error('Service Worker: Failed to clear caches', error);
    }
}

async function getCacheSize() {
    try {
        const cacheNames = await caches.keys();
        let totalSize = 0;

        for (const cacheName of cacheNames) {
            const cache = await caches.open(cacheName);
            const requests = await cache.keys();

            for (const request of requests) {
                const response = await cache.match(request);
                if (response) {
                    const blob = await response.blob();
                    totalSize += blob.size;
                }
            }
        }

        return totalSize;
    } catch (error) {
        console.error('Service Worker: Failed to calculate cache size', error);
        return 0;
    }
}

async function getPendingVideos() {
    // This would integrate with IndexedDB to store pending uploads
    // For now, return empty array
    return [];
}

async function uploadVideo(video) {
    // This would upload the video to a server
    // Implementation depends on your backend
    return Promise.resolve();
}

async function removePendingVideo(videoId) {
    // Remove video from pending uploads list
    // Implementation depends on storage mechanism
    return Promise.resolve();
}

// Periodic background sync for maintenance
self.addEventListener('periodicsync', (event) => {
    console.log('Service Worker: Periodic sync triggered', event.tag);

    if (event.tag === 'cleanup') {
        event.waitUntil(performMaintenance());
    }
});

async function performMaintenance() {
    try {
        // Clean up old cached videos
        const cache = await caches.open(DYNAMIC_CACHE_NAME);
        const requests = await cache.keys();
        const videoRequests = requests.filter(req => req.url.includes('/videos/'));

        // Keep only the most recent 50 videos
        if (videoRequests.length > 50) {
            const oldVideos = videoRequests.slice(0, videoRequests.length - 50);
            await Promise.all(oldVideos.map(req => cache.delete(req)));
            console.log('Service Worker: Cleaned up old cached videos');
        }

        // Clean up other temporary data
        // Add more cleanup logic as needed

    } catch (error) {
        console.error('Service Worker: Maintenance failed', error);
    }
}

// Error handling
self.addEventListener('error', (event) => {
    console.error('Service Worker: Error occurred', event.error);
});

self.addEventListener('unhandledrejection', (event) => {
    console.error('Service Worker: Unhandled promise rejection', event.reason);
});

console.log('Service Worker: Script loaded');
