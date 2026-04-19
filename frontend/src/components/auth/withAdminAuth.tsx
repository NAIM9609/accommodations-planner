import { useRouter } from 'next/router';
import { useEffect, type ComponentType } from 'react';
import { useAuth } from '../../contexts/AuthContext';

export default function withAdminAuth<P extends object>(
  WrappedComponent: ComponentType<P>,
): ComponentType<P> {
  function AdminAuthGuard(props: P): JSX.Element | null {
    const { isAuthenticated, isLoading } = useAuth();
    const router = useRouter();

    useEffect(() => {
      if (!isLoading && !isAuthenticated) {
        router.replace(`/login?returnTo=${encodeURIComponent(router.asPath)}`);
      }
    }, [isAuthenticated, isLoading, router]);

    if (isLoading) {
      return (
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'var(--lux-sand)',
          }}
          aria-busy="true"
          aria-label="Loading"
        >
          <p style={{ color: 'var(--lux-muted)', fontSize: '1rem' }}>Loading…</p>
        </div>
      );
    }

    if (!isAuthenticated) {
      return null;
    }

    return <WrappedComponent {...props} />;
  }

  AdminAuthGuard.displayName = `withAdminAuth(${WrappedComponent.displayName ?? WrappedComponent.name ?? 'Component'})`;

  return AdminAuthGuard;
}
