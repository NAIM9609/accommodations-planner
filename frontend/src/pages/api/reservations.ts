import type { NextApiRequest, NextApiResponse } from 'next';
import { handleProxyError, JSON_HEADERS, requireBackendUrl } from '../../lib/backendProxy';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const backendUrl = requireBackendUrl(res, {
    error: 'Server misconfiguration: BACKEND_API_URL is not set',
  });
  if (!backendUrl) return;

  try {
    if (req.method === 'GET') {
      // GET /api/reservations - fetch all reservations
      const response = await fetch(`${backendUrl}/reservations`, {
        method: 'GET',
        headers: JSON_HEADERS,
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: 'Failed to fetch reservations' });
      }

      const data = await response.json();
      return res.status(200).json(data);
    }

    if (req.method === 'POST') {
      // POST /api/reservations - create a reservation
      const response = await fetch(`${backendUrl}/reservations`, {
        method: 'POST',
        headers: JSON_HEADERS,
        body: JSON.stringify(req.body),
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: 'Failed to create reservation' });
      }

      const data = await response.json();
      return res.status(201).json(data);
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    return handleProxyError(res, error, { error: 'Internal server error' });
  }
}
