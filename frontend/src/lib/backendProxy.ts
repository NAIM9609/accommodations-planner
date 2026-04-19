import type { NextApiRequest, NextApiResponse } from 'next';

export const JSON_HEADERS = {
  'Content-Type': 'application/json',
} as const;

export function forwardAuthHeader(req: NextApiRequest): Record<string, string> {
  const auth = req.headers['authorization'];
  return auth ? { Authorization: auth } : {};
}

export function requireBackendUrl(
  res: NextApiResponse,
  errorBody: Record<string, string>,
): string | null {
  const backendUrl = process.env.BACKEND_API_URL;
  if (backendUrl) {
    return backendUrl;
  }

  console.error('BACKEND_API_URL environment variable is not set');
  res.status(500).json(errorBody);
  return null;
}

export function handleProxyError(
  res: NextApiResponse,
  error: unknown,
  responseBody: Record<string, string>,
  logPrefix = 'API Proxy Error',
): void {
  console.error(`${logPrefix}:`, error);
  res.status(500).json(responseBody);
}
