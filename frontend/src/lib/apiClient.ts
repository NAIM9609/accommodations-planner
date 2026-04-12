import { getApiBaseUrl } from './config';

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

export async function getReservations(): Promise<Reservation[]> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations`);
  if (!res.ok) throw new Error('Failed to fetch reservations');
  return res.json();
}

export async function createReservation(input: CreateReservationInput): Promise<Reservation> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  if (!res.ok) throw new Error('Failed to create reservation');
  return res.json();
}

export async function deleteReservation(id: string): Promise<void> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/reservations/${id}`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete reservation');
}
