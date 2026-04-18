import { getApiBaseUrl } from './config';

// ── AI types ────────────────────────────────────────────────

export interface ChatHistoryEntry {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatResponse {
  reply: string;
  modelId: string;
}

export interface RagCitation {
  text: string;
  references: { content: string; location: string }[];
}

export interface RagResponse {
  answer: string;
  citations: RagCitation[];
}

// ── Reservation types ────────────────────────────────────────

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

// ── AI functions ─────────────────────────────────────────────

export async function sendChatMessage(
  message: string,
  conversationHistory: ChatHistoryEntry[] = [],
): Promise<ChatResponse> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/ai/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, conversationHistory }),
  });
  if (!res.ok) throw new Error('Failed to send chat message');
  return res.json();
}

export async function askQuestion(question: string): Promise<RagResponse> {
  const BASE_URL = getApiBaseUrl();
  const res = await fetch(`${BASE_URL}/ai/rag`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ question }),
  });
  if (res.status === 503) {
    throw new Error('RAG_UNAVAILABLE');
  }
  if (!res.ok) throw new Error('Failed to ask question');
  return res.json();
}
