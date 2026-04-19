import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import type { ReactNode } from 'react';
import type { CognitoUser } from 'amazon-cognito-identity-js';
import {
  signIn,
  signOut,
  getCurrentSession,
  completeNewPasswordChallenge as submitNewPasswordChallenge,
} from '../lib/auth';

interface AuthChallengeState {
  type: 'NEW_PASSWORD_REQUIRED' | null;
  user: CognitoUser | null;
  userAttributes: Record<string, string> | null;
}

interface AuthContextValue {
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  challengeState: AuthChallengeState;
  completeNewPasswordChallenge: (newPassword: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [challengeState, setChallengeState] = useState<AuthChallengeState>({
    type: null,
    user: null,
    userAttributes: null,
  });

  useEffect(() => {
    getCurrentSession()
      .then((session) => setIsAuthenticated(session !== null))
      .catch(() => setIsAuthenticated(false))
      .finally(() => setIsLoading(false));
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const result = await signIn(email, password);

    if ('challengeName' in result && result.challengeName === 'NEW_PASSWORD_REQUIRED') {
      setChallengeState({
        type: result.challengeName,
        user: result.user,
        userAttributes: result.userAttributes,
      });
      return;
    }

    setChallengeState({ type: null, user: null, userAttributes: null });
    setIsAuthenticated(true);
  }, []);

  const completeNewPasswordChallenge = useCallback(
    async (newPassword: string) => {
      if (!challengeState.user || !challengeState.userAttributes) {
        throw new Error('Password setup session expired. Please log in again.');
      }

      await submitNewPasswordChallenge(
        challengeState.user,
        newPassword,
        challengeState.userAttributes,
      );

      setChallengeState({ type: null, user: null, userAttributes: null });
      setIsAuthenticated(true);
    },
    [challengeState],
  );

  const logout = useCallback(() => {
    signOut();
    setChallengeState({ type: null, user: null, userAttributes: null });
    setIsAuthenticated(false);
    router.push('/login');
  }, [router]);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isLoading,
        login,
        challengeState,
        completeNewPasswordChallenge,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used inside <AuthProvider>');
  }
  return ctx;
}
