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
    }}>
      {label}
    </Link>
  );

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif', background: '#f8f9fa' }}>
      <header style={{
        background: 'white',
        borderBottom: '1px solid #e9ecef',
        position: 'sticky',
        top: 0,
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
      }}>
        <nav style={{
          maxWidth: 1100,
          margin: '0 auto',
          padding: '0 20px',
          height: '64px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}>
          <Link href="/" style={{
            textDecoration: 'none',
            color: '#333',
            fontWeight: 800,
            fontSize: '1.2rem',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}>
            🏡 Maple Grove B&amp;B
          </Link>
          <div style={{ display: 'flex', gap: '4px' }}>
            {navLink('/', 'Home')}
            {navLink('/reservations', 'Reservations')}
          </div>
        </nav>
      </header>

      <main style={{ flex: 1 }}>
        {children}
      </main>

      <footer style={{
        background: '#2d3748',
        color: '#a0aec0',
        textAlign: 'center',
        padding: '32px 20px',
        marginTop: 'auto',
      }}>
        <p style={{ margin: '0 0 8px', color: 'white', fontWeight: 600 }}>🏡 Maple Grove B&amp;B</p>
        <p style={{ margin: '0 0 8px', fontSize: '0.9rem' }}>123 Maple Lane, Greenwood Valley · (555) 867-5309</p>
        <p style={{ margin: 0, fontSize: '0.8rem' }}>
          © {new Date().getFullYear()} Maple Grove B&amp;B. All rights reserved.
        </p>
      </footer>
    </div>
  );
}
