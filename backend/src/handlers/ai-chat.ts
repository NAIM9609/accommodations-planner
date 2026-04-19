import { ConverseCommand } from '@aws-sdk/client-bedrock-runtime';
import { APIGatewayProxyHandler } from 'aws-lambda';

import { BEDROCK_MODEL_ID, bedrockRuntime } from '../lib/bedrock';
import { respond } from '../lib/http';

const SYSTEM_PROMPT =
  'You are a helpful assistant for an accommodations booking platform. ' +
  'Help guests with questions about rooms, availability, pricing, and reservations.';

interface HistoryEntry {
  role: 'user' | 'assistant';
  content: string;
}

export const handler: APIGatewayProxyHandler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return respond(204, null, event.headers);
  }

  let body: { message?: unknown; conversationHistory?: unknown };
  try {
    body = JSON.parse(event.body ?? 'null');
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
  } catch {
    return respond(400, { message: 'Invalid JSON body' }, event.headers);
  }

  if (!body.message || typeof body.message !== 'string' || !body.message.trim()) {
    return respond(400, { message: 'Missing required field: message' }, event.headers);
  }

  const history: HistoryEntry[] = [];
  if (Array.isArray(body.conversationHistory)) {
    for (const entry of body.conversationHistory) {
      if (
        entry &&
        typeof entry === 'object' &&
        (entry.role === 'user' || entry.role === 'assistant') &&
        typeof entry.content === 'string'
      ) {
        history.push({ role: entry.role as 'user' | 'assistant', content: entry.content });
      }
    }
  }

  try {
    const messages = [
      ...history.map((m) => ({
        role: m.role,
        content: [{ text: m.content }],
      })),
      {
        role: 'user' as const,
        content: [{ text: body.message as string }],
      },
    ];

    const result = await bedrockRuntime.send(
      new ConverseCommand({
        modelId: BEDROCK_MODEL_ID,
        messages,
        system: [{ text: SYSTEM_PROMPT }],
      }),
    );

    const reply = result.output?.message?.content?.[0]?.text ?? '';
    return respond(200, { reply, modelId: BEDROCK_MODEL_ID }, event.headers);
  } catch (err) {
    console.error(err);
    return respond(500, { message: 'Internal server error' }, event.headers);
  }
};
