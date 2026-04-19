import type { NextApiRequest, NextApiResponse } from 'next';
import { forwardAuthHeader, handleProxyError, JSON_HEADERS, requireBackendUrl } from '../../../lib/backendProxy';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const backendUrl = requireBackendUrl(res, {
    error: 'Server misconfiguration: BACKEND_API_URL is not set',
  });
  if (!backendUrl) return;

  const { id } = req.query;
  const authHeader = forwardAuthHeader(req);

  try {
    if (req.method === 'DELETE') {
      if (!id || Array.isArray(id)) {
        return res.status(400).json({ error: 'Invalid reservation ID' });
      }

      // DELETE /api/reservations/[id] - delete a specific reservation
      const response = await fetch(`${backendUrl}/reservations/${id}`, {
        method: 'DELETE',
        headers: { ...JSON_HEADERS, ...authHeader },
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: 'Failed to delete reservation' });
      }

      return res.status(204).end();
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    return handleProxyError(res, error, { error: 'Internal server error' });
  }
}
