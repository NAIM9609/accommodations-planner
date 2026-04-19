/**
 * Centralized API configuration
 * Handles local development vs production API endpoints
 */

export const getApiBaseUrl = (): string => {
  // Always route through the Next.js API proxy so requests are server-side
  // and CORS is never a concern. Set BACKEND_API_URL (server-side only) to
  // the API Gateway URL in your hosting environment (e.g. Amplify env vars).
  return '/api';
};

export const getCognitoUserPoolId = (): string => {
  const value = process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID;
  if (!value) {
    throw new Error('Missing required env var: NEXT_PUBLIC_COGNITO_USER_POOL_ID');
  }
  return value;
};

export const getCognitoClientId = (): string => {
  const value = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID;
  if (!value) {
    throw new Error('Missing required env var: NEXT_PUBLIC_COGNITO_CLIENT_ID');
  }
  return value;
};
