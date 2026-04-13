import type { NextApiRequest, NextApiResponse } from 'next';
import { handleProxyError, JSON_HEADERS, requireBackendUrl } from '../../lib/backendProxy';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const backendUrl = requireBackendUrl(res, {
    status: 'unhealthy',
    error: 'Server misconfiguration: BACKEND_API_URL is not set',
  });
  if (!backendUrl) return;

  try {
    const response = await fetch(`${backendUrl}/health`, {
      method: 'GET',
      headers: JSON_HEADERS,
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return handleProxyError(
      res,
      error,
      { status: 'unhealthy', error: 'Service unavailable' },
      'Health check error',
    );
  }
}
