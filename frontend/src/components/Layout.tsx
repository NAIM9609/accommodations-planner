import Head from 'next/head';
import Link from 'next/link';
import { useRouter } from 'next/router';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { BRAND } from '../lib/brand';
import LanguageSwitcher from './LanguageSwitcher';
import { useAuth } from '../contexts/AuthContext';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const router = useRouter();
  const { t } = useTranslation();
  const { isAuthenticated, logout } = useAuth();

  const navLink = (href: string, label: string) => (
    <Link href={href} style={{
      color: router.pathname === href ? '#1f3b35' : '#495a54',
      textDecoration: 'none',
      fontWeight: router.pathname === href ? 700 : 500,
      padding: '8px 16px',
      borderRadius: '6px',
      background: router.pathname === href ? 'rgba(179, 144, 82, 0.14)' : 'transparent',
      /* Minimum 48px touch target (WCAG 2.5.8) */
      minHeight: '44px',
      display: 'inline-flex',
      alignItems: 'center',
    }}>
      {label}
    </Link>
  );

  return (
    <>
      <Head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
        {/* Skip link — first focusable element (WCAG 2.4.1) */}
        <a href="#main-content" className="skip-link">{t('nav.skipToMain')}</a>

        <header style={{
          background: '#fdf9f2',
          borderBottom: '1px solid #e3d9c9',
          position: 'sticky',
          top: 0,
          zIndex: 100,
          boxShadow: '0 2px 10px rgba(31,38,35,0.05)',
        }}>
          <nav className="site-nav" aria-label="Main">
            <Link href="/" className="site-nav__logo">
              🏡 {BRAND.shortName}
            </Link>
            <div className="site-nav__links">
              {navLink('/', t('nav.home'))}
              {isAuthenticated ? navLink('/reservations', t('nav.reservations')) : null}
              {isAuthenticated ? (
                <button
                  type="button"
                  onClick={logout}
                  style={{
                    color: '#495a54',
                    background: 'transparent',
                    border: 'none',
                    fontWeight: 500,
                    padding: '8px 16px',
                    borderRadius: '6px',
                    minHeight: '44px',
                    cursor: 'pointer',
                    fontFamily: 'inherit',
                    fontSize: 'inherit',
                  }}
                >
                  {t('auth.signOut')}
                </button>
              ) : (
                navLink('/login', t('auth.signIn'))
              )}
            </div>
            <LanguageSwitcher />
          </nav>
        </header>

        <main id="main-content" style={{ flex: 1 }} tabIndex={-1}>
          {children}
        </main>

        <footer style={{
          background: '#1f2e2a',
          color: '#d2dfd9',
          textAlign: 'center',
          padding: '32px 16px',
          marginTop: 'auto',
        }}>
          <p style={{ margin: '0 0 8px', color: 'white', fontWeight: 600 }}>🏡 {BRAND.shortName}</p>
          <p style={{ margin: '0 0 8px', fontSize: '0.9rem' }}>{BRAND.locationLine} · {BRAND.phone}</p>
          <p style={{ margin: 0, fontSize: '0.8rem' }}>
            © <span>{BRAND.copyrightYear}</span> {BRAND.shortName}. {t('footer.allRightsReserved')}
          </p>
        </footer>
      </div>
    </>
  );
}
