import { getApiBaseUrl } from './config';
import { getAccessToken } from './auth';

export interface Reservation {
  id: string;
  guestName: string;
  guestEmail: string;
  checkIn: string;
  checkOut: string;
  roomType: string;
  createdAt: string;
}

export interface CreateReservationInput {
  guestName: string;
  guestEmail: string;
  checkIn: string;
  checkOut: string;
  roomType: string;
}

async function authHeaders(): Promise<Record<string, string>> {
  const token = await getAccessToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function handleUnauthorized(res: Response): void {
  if (res.status === 401 && typeof window !== 'undefined') {
    window.location.href = `/login?returnTo=${encodeURIComponent(window.location.pathname)}`;
  }
}

export async function getReservations(): Promise<Reservation[]> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations`, {
    headers: await authHeaders(),
  });
  handleUnauthorized(res);
  if (!res.ok) throw new Error('Failed to fetch reservations');
  return res.json();
}

export async function createReservation(input: CreateReservationInput): Promise<Reservation> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(await authHeaders()) },
    body: JSON.stringify(input),
  });
  handleUnauthorized(res);
  if (!res.ok) throw new Error('Failed to create reservation');
  return res.json();
}

export async function deleteReservation(id: string): Promise<void> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations/${id}`, {
    method: 'DELETE',
    headers: await authHeaders(),
  });
  handleUnauthorized(res);
  if (!res.ok) throw new Error('Failed to delete reservation');
}
