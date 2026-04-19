/**
 * Centralized API configuration
 * Handles local development vs production API endpoints
 */

export const getApiBaseUrl = (): string => {
  // In production, call the API Gateway directly via NEXT_PUBLIC_API_BASE_URL.
  // In local development, fall back to the Next.js dev-server API proxy.
  return process.env.NEXT_PUBLIC_API_BASE_URL || '/api';
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
