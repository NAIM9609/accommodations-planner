import type { NextApiRequest, NextApiResponse } from 'next';
import { handleProxyError, JSON_HEADERS, requireBackendUrl } from '../../../lib/backendProxy';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const backendUrl = requireBackendUrl(res, {
    error: 'Server misconfiguration: BACKEND_API_URL is not set',
  });
  if (!backendUrl) return;

  try {
    const response = await fetch(`${backendUrl}/ai/rag`, {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify(req.body),
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return handleProxyError(res, error, { error: 'Internal server error' });
  }
}
