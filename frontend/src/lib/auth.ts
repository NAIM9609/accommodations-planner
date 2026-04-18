import {
  CognitoUser,
  CognitoUserPool,
  AuthenticationDetails,
  CognitoUserSession,
} from 'amazon-cognito-identity-js';
import { getCognitoUserPoolId, getCognitoClientId } from './config';

function getUserPool(): CognitoUserPool {
  return new CognitoUserPool({
    UserPoolId: getCognitoUserPoolId(),
    ClientId: getCognitoClientId(),
  });
}

export function signIn(email: string, password: string): Promise<CognitoUserSession> {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: email, Pool: getUserPool() });
    const auth = new AuthenticationDetails({ Username: email, Password: password });

    user.authenticateUser(auth, {
      onSuccess: resolve,
      onFailure: reject,
      newPasswordRequired: () =>
        reject(new Error('Password reset required. Please contact your administrator.')),
    });
  });
}

export function signOut(): void {
  const user = getUserPool().getCurrentUser();
  if (user) {
    user.signOut();
  }
}

export function getCurrentSession(): Promise<CognitoUserSession | null> {
  return new Promise((resolve) => {
    const user = getUserPool().getCurrentUser();
    if (!user) {
      resolve(null);
      return;
    }

    user.getSession((err: Error | null, session: CognitoUserSession | null) => {
      if (err || !session || !session.isValid()) {
        resolve(null);
      } else {
        resolve(session);
      }
    });
  });
}

export async function getAccessToken(): Promise<string | null> {
  const session = await getCurrentSession();
  return session ? session.getAccessToken().getJwtToken() : null;
}
