import Head from 'next/head';
import Link from 'next/link';
import { useRouter } from 'next/router';
import type { ReactNode } from 'react';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const router = useRouter();

  const navLink = (href: string, label: string) => (
    <Link href={href} style={{
      color: router.pathname === href ? '#764ba2' : '#555',
      textDecoration: 'none',
      fontWeight: router.pathname === href ? 700 : 500,
      padding: '8px 16px',
      borderRadius: '6px',
      background: router.pathname === href ? 'rgba(118, 75, 162, 0.08)' : 'transparent',
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
        <a href="#main-content" className="skip-link">Skip to main content</a>

        <header style={{
          background: 'white',
          borderBottom: '1px solid #e9ecef',
          position: 'sticky',
          top: 0,
          zIndex: 100,
          boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
        }}>
          <nav className="site-nav" aria-label="Main">
            <Link href="/" className="site-nav__logo">
              🏡 Maple Grove B&amp;B
            </Link>
            <div className="site-nav__links">
              {navLink('/', 'Home')}
              {navLink('/reservations', 'Reservations')}
            </div>
          </nav>
        </header>

        <main id="main-content" style={{ flex: 1 }} tabIndex={-1}>
          {children}
        </main>

        <footer style={{
          background: '#2d3748',
          color: '#a0aec0',
          textAlign: 'center',
          padding: '32px 16px',
          marginTop: 'auto',
        }}>
          <p style={{ margin: '0 0 8px', color: 'white', fontWeight: 600 }}>🏡 Maple Grove B&amp;B</p>
          <p style={{ margin: '0 0 8px', fontSize: '0.9rem' }}>123 Maple Lane, Greenwood Valley · (555) 867-5309</p>
          <p style={{ margin: 0, fontSize: '0.8rem' }}>
            © <span suppressHydrationWarning>{new Date().getFullYear()}</span> Maple Grove B&amp;B. All rights reserved.
          </p>
        </footer>
      </div>
    </>
  );
}
