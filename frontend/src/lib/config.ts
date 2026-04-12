/**
 * Centralized API configuration
 * Handles local development vs production API endpoints
 */

export const getApiBaseUrl = (): string => {
  // Always use relative API routes (routed to backend via server-side proxies)
  return '/api';
};

export const apiConfig = {
  baseUrl: getApiBaseUrl(),
  timeout: 30000,
  retries: 3,
} as const;
