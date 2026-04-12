/**
 * Centralized API configuration
 * Handles local development vs production API endpoints
 */

export const getApiBaseUrl = (): string => {
  // In production, call the API Gateway directly via NEXT_PUBLIC_API_BASE_URL.
  // In local development, fall back to the Next.js dev-server API proxy.
  return process.env.NEXT_PUBLIC_API_BASE_URL || '/api';
};

export const apiConfig = {
  baseUrl: getApiBaseUrl(),
  timeout: 30000,
  retries: 3,
} as const;
