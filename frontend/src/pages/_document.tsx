import { Head, Html, Main, NextScript } from 'next/document';

const DEV_SW_CLEANUP = `
  (function () {
    try {
      var isDevHost = /^(localhost|127\\.0\\.0\\.1)$/i.test(window.location.hostname);
      if (!isDevHost) return;

      var didReload = sessionStorage.getItem('sw-cleanup-reloaded') === '1';

      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistrations().then(function (registrations) {
          return Promise.all(registrations.map(function (registration) {
            return registration.unregister().catch(function () { return false; });
          }));
        }).catch(function () {});
      }

      if ('caches' in window) {
        caches.keys().then(function (keys) {
          return Promise.all(keys.map(function (key) { return caches.delete(key); }));
        }).catch(function () {});
      }

      if (navigator.serviceWorker && navigator.serviceWorker.controller && !didReload) {
        sessionStorage.setItem('sw-cleanup-reloaded', '1');
        window.location.reload();
      }
    } catch (e) {}
  })();
`;

export default function Document(): JSX.Element {
  const isDevelopment = process.env.NODE_ENV === 'development';

  return (
    <Html>
      <Head>
        {isDevelopment ? <script dangerouslySetInnerHTML={{ __html: DEV_SW_CLEANUP }} /> : null}
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
