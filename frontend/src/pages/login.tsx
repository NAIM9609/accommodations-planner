import Head from 'next/head';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { BRAND } from '../lib/brand';

export default function LoginPage(): JSX.Element {
  const { t } = useTranslation();
  const router = useRouter();
  const {
    isAuthenticated,
    isLoading,
    login,
    challengeState,
    completeNewPasswordChallenge,
  } = useAuth();

  // Use an explicit allowlist to prevent open redirect attacks.
  // Any returnTo value not in this list falls back to the default.
  const ALLOWED_RETURN_PATHS = ['/reservations', '/help', '/'];
  const rawReturn = typeof router.query.returnTo === 'string' ? router.query.returnTo : '';
  const returnTo = ALLOWED_RETURN_PATHS.includes(rawReturn) ? rawReturn : '/reservations';

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const isNewPasswordStep = challengeState.type === 'NEW_PASSWORD_REQUIRED';
  const challengeUsername = email || challengeState.userAttributes?.email || '';

  // If already authenticated, redirect immediately
  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.replace(returnTo);
    }
  }, [isAuthenticated, isLoading, router, returnTo]);

  const handleInitialSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(email, password);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message || t('auth.errorGeneric'));
    } finally {
      setSubmitting(false);
    }
  };

  const handleNewPasswordSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);

    if (newPassword !== confirmPassword) {
      setError(t('auth.passwordMismatch'));
      return;
    }

    setSubmitting(true);
    try {
      await completeNewPasswordChallenge(newPassword);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message || t('auth.challengeExpired'));
    } finally {
      setSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--lux-sand)' }}>
        <p style={{ color: 'var(--lux-muted)', fontSize: '1rem' }}>{t('auth.checkingSession')}</p>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>{`${t('auth.pageTitle')} | ${BRAND.fullName}`}</title>
        <meta name="robots" content="noindex" />
      </Head>

      <div style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--lux-sand)',
        padding: '24px 16px',
      }}>
        <div style={{
          width: '100%',
          maxWidth: '420px',
          background: '#fff',
          borderRadius: '12px',
          border: '1px solid var(--lux-line)',
          padding: '40px 32px',
          boxShadow: '0 4px 24px rgba(31,38,35,0.07)',
        }}>
          {/* Logo / brand */}
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            <Link href="/" style={{ textDecoration: 'none', color: 'var(--lux-ink)' }}>
              <span style={{ fontSize: '1.5rem' }}>🏡</span>
              <p style={{
                margin: '8px 0 0',
                fontFamily: 'var(--lux-serif)',
                fontSize: '1.1rem',
                fontWeight: 500,
                color: 'var(--lux-ink)',
              }}>
                {BRAND.shortName}
              </p>
            </Link>
            <h1 style={{
              margin: '16px 0 0',
              fontSize: '1.25rem',
              fontWeight: 600,
              color: 'var(--lux-ink)',
              letterSpacing: '-0.01em',
            }}>
              {isNewPasswordStep ? t('auth.newPasswordRequired') : t('auth.heading')}
            </h1>
          </div>

          <form onSubmit={isNewPasswordStep ? handleNewPasswordSubmit : handleInitialSubmit} noValidate>
            {isNewPasswordStep ? (
              <>
                <input
                  type="email"
                  name="username"
                  autoComplete="username"
                  value={challengeUsername}
                  readOnly
                  tabIndex={-1}
                  style={{
                    position: 'absolute',
                    width: '1px',
                    height: '1px',
                    padding: 0,
                    margin: '-1px',
                    overflow: 'hidden',
                    clip: 'rect(0, 0, 0, 0)',
                    border: 0,
                  }}
                />

                <p
                  style={{
                    margin: '0 0 16px',
                    color: 'var(--lux-muted)',
                    fontSize: '0.95rem',
                    lineHeight: 1.4,
                  }}
                >
                  {t('auth.newPasswordDesc')}
                </p>

                <div style={{ marginBottom: '16px' }}>
                  <label
                    htmlFor="login-new-password"
                    style={{ display: 'block', marginBottom: '6px', fontWeight: 600, fontSize: '0.875rem', color: 'var(--lux-ink)' }}
                  >
                    {t('auth.newPasswordLabel')}
                  </label>
                  <input
                    id="login-new-password"
                    type="password"
                    autoComplete="new-password"
                    required
                    minLength={8}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    aria-invalid={error ? 'true' : 'false'}
                    aria-describedby={error ? 'login-error' : 'login-password-rules'}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '6px',
                      border: `1px solid ${error ? '#c0392b' : 'var(--lux-line)'}`,
                      fontSize: '1rem',
                      color: 'var(--lux-ink)',
                      background: '#fafafa',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                <div style={{ marginBottom: '12px' }}>
                  <label
                    htmlFor="login-confirm-password"
                    style={{ display: 'block', marginBottom: '6px', fontWeight: 600, fontSize: '0.875rem', color: 'var(--lux-ink)' }}
                  >
                    {t('auth.confirmPasswordLabel')}
                  </label>
                  <input
                    id="login-confirm-password"
                    type="password"
                    autoComplete="new-password"
                    required
                    minLength={8}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    aria-invalid={error ? 'true' : 'false'}
                    aria-describedby={error ? 'login-error' : 'login-password-rules'}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '6px',
                      border: `1px solid ${error ? '#c0392b' : 'var(--lux-line)'}`,
                      fontSize: '1rem',
                      color: 'var(--lux-ink)',
                      background: '#fafafa',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                <p
                  id="login-password-rules"
                  style={{
                    margin: '0 0 20px',
                    color: 'var(--lux-muted)',
                    fontSize: '0.8125rem',
                    lineHeight: 1.5,
                  }}
                >
                  {t('auth.passwordRequirements')}
                </p>
              </>
            ) : (
              <>
                {/* Email */}
                <div style={{ marginBottom: '16px' }}>
                  <label
                    htmlFor="login-email"
                    style={{ display: 'block', marginBottom: '6px', fontWeight: 600, fontSize: '0.875rem', color: 'var(--lux-ink)' }}
                  >
                    {t('auth.emailLabel')}
                  </label>
                  <input
                    id="login-email"
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    aria-invalid={error ? 'true' : 'false'}
                    aria-describedby={error ? 'login-error' : undefined}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '6px',
                      border: `1px solid ${error ? '#c0392b' : 'var(--lux-line)'}`,
                      fontSize: '1rem',
                      color: 'var(--lux-ink)',
                      background: '#fafafa',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                {/* Password */}
                <div style={{ marginBottom: '24px' }}>
                  <label
                    htmlFor="login-password"
                    style={{ display: 'block', marginBottom: '6px', fontWeight: 600, fontSize: '0.875rem', color: 'var(--lux-ink)' }}
                  >
                    {t('auth.passwordLabel')}
                  </label>
                  <input
                    id="login-password"
                    type="password"
                    autoComplete="current-password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    aria-invalid={error ? 'true' : 'false'}
                    aria-describedby={error ? 'login-error' : undefined}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '6px',
                      border: `1px solid ${error ? '#c0392b' : 'var(--lux-line)'}`,
                      fontSize: '1rem',
                      color: 'var(--lux-ink)',
                      background: '#fafafa',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>
              </>
            )}

            {/* Inline error */}
            {error ? (
              <p
                id="login-error"
                role="alert"
                style={{
                  margin: '0 0 16px',
                  padding: '10px 14px',
                  borderRadius: '6px',
                  background: '#fff5f5',
                  border: '1px solid #fca5a5',
                  color: '#c0392b',
                  fontSize: '0.875rem',
                }}
              >
                {error}
              </p>
            ) : null}

            <button
              type="submit"
              disabled={submitting}
              className="lux-btn lux-btn--solid"
              style={{ width: '100%', cursor: submitting ? 'not-allowed' : 'pointer', opacity: submitting ? 0.7 : 1 }}
            >
              {submitting
                ? (isNewPasswordStep ? t('auth.settingPassword') : t('auth.signingIn'))
                : (isNewPasswordStep ? t('auth.changePassword') : t('auth.signIn'))}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
