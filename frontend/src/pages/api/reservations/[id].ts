import type { NextApiRequest, NextApiResponse } from 'next';

// Backend API URL must be set via environment variables
const BACKEND_URL = process.env.BACKEND_API_URL;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (!BACKEND_URL) {
    console.error('BACKEND_API_URL environment variable is not set');
    return res.status(500).json({ error: 'Server misconfiguration: BACKEND_API_URL is not set' });
  }

  const { id } = req.query;

  try {
    if (req.method === 'DELETE') {
      if (!id || Array.isArray(id)) {
        return res.status(400).json({ error: 'Invalid reservation ID' });
      }

      // DELETE /api/reservations/[id] - delete a specific reservation
      const response = await fetch(`${BACKEND_URL}/reservations/${id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: 'Failed to delete reservation' });
      }

      return res.status(204).end();
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error('API Proxy Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
