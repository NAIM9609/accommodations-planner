import '../styles/globals.css';
import '../i18n';
import { useEffect } from 'react';
import type { AppProps } from 'next/app';
import { detectAndApplyLanguage } from '../i18n';

export default function App({ Component, pageProps }: AppProps) {
  useEffect(() => {
    detectAndApplyLanguage();
  }, []);

  return <Component {...pageProps} />;
}
