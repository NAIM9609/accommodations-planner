import {
  CognitoUser,
  CognitoUserPool,
  AuthenticationDetails,
  CognitoUserSession,
} from 'amazon-cognito-identity-js';
import { getCognitoUserPoolId, getCognitoClientId } from './config';

export interface NewPasswordRequiredChallenge {
  challengeName: 'NEW_PASSWORD_REQUIRED';
  user: CognitoUser;
  userAttributes: Record<string, string>;
}

function getUserPool(): CognitoUserPool {
  return new CognitoUserPool({
    UserPoolId: getCognitoUserPoolId(),
    ClientId: getCognitoClientId(),
  });
}

export function signIn(
  email: string,
  password: string,
): Promise<CognitoUserSession | NewPasswordRequiredChallenge> {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: email, Pool: getUserPool() });
    const auth = new AuthenticationDetails({ Username: email, Password: password });

    user.authenticateUser(auth, {
      onSuccess: resolve,
      onFailure: reject,
      newPasswordRequired: (attributes) =>
        resolve({
          challengeName: 'NEW_PASSWORD_REQUIRED',
          user,
          userAttributes: attributes as Record<string, string>,
        }),
    });
  });
}

export function completeNewPasswordChallenge(
  user: CognitoUser,
  newPassword: string,
  userAttributes: Record<string, string>,
): Promise<CognitoUserSession> {
  return new Promise((resolve, reject) => {
    user.completeNewPasswordChallenge(newPassword, userAttributes, {
      onSuccess: resolve,
      onFailure: reject,
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
