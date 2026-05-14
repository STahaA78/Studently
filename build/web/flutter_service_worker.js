'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "9a086327383a9a65589b1044cacfcebc",
"assets/AssetManifest.bin.json": "023f1f125bea96c74bafacb5246c7ae2",
"assets/AssetManifest.json": "9bbc10c758c64d02a9ff108a62507db5",
"assets/assets/images/connect-filled.svg": "8eed45799fbe11fc8c4fd6a1e2ded8d0",
"assets/assets/images/connect-outlined.svg": "fe7d1efbd2be8612ab3ebdaaa55249e7",
"assets/assets/images/feed-filled.svg": "f51c5cbd452c060d24d604768d99d68f",
"assets/assets/images/feed-outlined.svg": "898b2670b2d09c5853626bacb77c1b34",
"assets/assets/images/friend-requests.svg": "1424c3c1db8bcc33c81dd3365d95de6c",
"assets/assets/images/google_icon.svg": "95e2a6d013d7b5dad7ce5d48e26b6be7",
"assets/assets/images/knowledgehub-filled.svg": "ae161ea79c5db70b640f7a319ad45976",
"assets/assets/images/knowledgehub-outlined.svg": "ab6b516fcb670e3606f72e5057ad825c",
"assets/assets/images/logo.png": "94430ad4e3787da016de2c1837b41fd7",
"assets/assets/images/logo.svg": "4a759f6d8c0efb07f0161d69df44ce74",
"assets/assets/images/messages.svg": "c48ce62e77af5cdcd95540aa139804aa",
"assets/assets/images/notifications.svg": "077bc468a7800e5274e0c82287f600f4",
"assets/assets/images/post.svg": "1252e73276ee36d6c7eac9fe6ab4f25e",
"assets/assets/images/profile-filled.svg": "12bc736eee54b923f8e264d7513daff1",
"assets/assets/images/profile-outlined.svg": "800589f0b54550909310b08062023b19",
"assets/FontManifest.json": "2b52acee7bee9f34d372a965ef37754f",
"assets/fonts/MaterialIcons-Regular.otf": "c250de2c321558c09d93033503714b4f",
"assets/NOTICES": "cc22b0339e52dca411ce4f6ce69e31fc",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/packages/syncfusion_flutter_pdfviewer/assets/fonts/RobotoMono-Regular.ttf": "5b04fdfec4c8c36e8ca574e40b7148bb",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/dark/highlight.png": "2aecc31aaa39ad43c978f209962a985c",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/dark/squiggly.png": "68960bf4e16479abb83841e54e1ae6f4",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/dark/strikethrough.png": "72e2d23b4cdd8a9e5e9cadadf0f05a3f",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/dark/underline.png": "59886133294dd6587b0beeac054b2ca3",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/light/highlight.png": "2fbda47037f7c99871891ca5e57e030b",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/light/squiggly.png": "9894ce549037670d25d2c786036b810b",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/light/strikethrough.png": "26f6729eee851adb4b598e3470e73983",
"assets/packages/syncfusion_flutter_pdfviewer/assets/icons/light/underline.png": "a98ff6a28215341f764f96d627a5d0f5",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "94430ad4e3787da016de2c1837b41fd7",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "477542bd5831f23413eb7151df29d94f",
"icons/icon-128x128.png": "6aa54e6fa5d05a94159853553b597fb0",
"icons/icon-144x144.png": "4060ad0d18714289deee9fc67f261a7e",
"icons/icon-152x152.png": "1416512d21a982fad6a7209f663c1b0e",
"icons/icon-192x192.png": "0b7bdeab9d6ba3f646c7c3c2d2082747",
"icons/icon-256x256.png": "337ff8543d5597388ef46c376582008c",
"icons/icon-384x384.png": "ab2698e48fde603fd0ef38a9113cdb6e",
"icons/icon-48x48.png": "fad3afb11b28e3466a052beb8e59c88d",
"icons/icon-512x512.png": "4a51174c0dd37dbce654c14af30730ba",
"icons/icon-72x72.png": "2cc610b6c9ec70dcdcde4ea4daa46859",
"icons/icon-96x96.png": "b41cbb94b1e58af5f08ea693408b9f72",
"index.html": "badb183d604d6d5bc4c86c7a589a8c5a",
"/": "badb183d604d6d5bc4c86c7a589a8c5a",
"main.dart.js": "f5d7f8d8fa059afa344a6e0eafec6deb",
"manifest.json": "d312848d7626f4eb058017fee7c75149",
"splash/img/dark-1x.png": "938f20e656b9119b058c28a9425e435a",
"splash/img/dark-2x.png": "0453df5aaea9a3812e2024ec4d361984",
"splash/img/dark-3x.png": "4b344a6819bca6ba7e2354e7f8f561a8",
"splash/img/dark-4x.png": "752fbb489be4a3d9cbb813b333658050",
"splash/img/light-1x.png": "938f20e656b9119b058c28a9425e435a",
"splash/img/light-2x.png": "0453df5aaea9a3812e2024ec4d361984",
"splash/img/light-3x.png": "4b344a6819bca6ba7e2354e7f8f561a8",
"splash/img/light-4x.png": "752fbb489be4a3d9cbb813b333658050",
"version.json": "c3de19033e43d13519c44043031c6bc5"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
