import type { NextApiRequest, NextApiResponse } from 'next';

// Backend API URL must be set via environment variables
const BACKEND_URL = process.env.BACKEND_API_URL;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const response = await fetch(`${BACKEND_URL}/health`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Health check error:', error);
    return res.status(503).json({ status: 'unhealthy', error: 'Service unavailable' });
  }
}
