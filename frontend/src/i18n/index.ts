import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from './locales/en.json';
import it from './locales/it.json';
import es from './locales/es.json';
import de from './locales/de.json';

export const SUPPORTED_LANGS = ['en', 'it', 'es', 'de'] as const;
export const DEFAULT_LNG = 'en';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      it: { translation: it },
      es: { translation: es },
      de: { translation: de },
    },
    lng: DEFAULT_LNG,
    fallbackLng: DEFAULT_LNG,
    supportedLngs: SUPPORTED_LANGS,
    interpolation: {
      escapeValue: false,
    },
  });

/**
 * Detect the user's preferred language from localStorage or the browser
 * and apply it. Call this once after hydration (inside a useEffect).
 */
export function detectAndApplyLanguage() {
  const stored = typeof window !== 'undefined'
    ? localStorage.getItem('i18nextLng')
    : null;
  const detected = stored
    ?? (typeof navigator !== 'undefined' ? navigator.language?.split('-')[0] : null);
  const lang = SUPPORTED_LANGS.includes(detected as any) ? detected! : DEFAULT_LNG;

  if (i18n.language !== lang) {
    i18n.changeLanguage(lang);
  }
}

export default i18n;
