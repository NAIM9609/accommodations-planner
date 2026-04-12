import type { NextApiRequest, NextApiResponse } from 'next';

// Backend API URL must be set via environment variables
const BACKEND_URL = process.env.BACKEND_API_URL;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    if (req.method === 'GET') {
      // GET /api/reservations - fetch all reservations
      const response = await fetch(`${BACKEND_URL}/reservations`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        return res.status(response.status).json({ error: 'Failed to fetch reservations' });
      }

      const data = await response.json();
      return res.status(200).json(data);
    }

    if (req.method === 'POST') {
      // POST /api/reservations - create a reservation
      const response = await fetch(`${BACKEND_URL}/reservations`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
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
    console.error('API Proxy Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
