import { APIGatewayProxyEvent, Context } from 'aws-lambda';

import { handler } from '../src/handlers/ai-chat';

jest.mock('../src/lib/bedrock', () => ({
  bedrockRuntime: { send: jest.fn() },
  BEDROCK_MODEL_ID: 'anthropic.claude-3-haiku-20240307-v1:0',
}));

import { bedrockRuntime } from '../src/lib/bedrock';
const mockSend = bedrockRuntime.send as jest.Mock;

const ctx = {} as Context;

function makeEvent(overrides: Partial<APIGatewayProxyEvent>): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    path: '/ai/chat',
    pathParameters: null,
    queryStringParameters: null,
    headers: {},
    multiValueHeaders: {},
    body: null,
    isBase64Encoded: false,
    resource: '',
    stageVariables: null,
    requestContext: {} as APIGatewayProxyEvent['requestContext'],
    multiValueQueryStringParameters: null,
    ...overrides,
  };
}

beforeEach(() => mockSend.mockReset());

test('OPTIONS /ai/chat returns 204', async () => {
  const result = await handler(makeEvent({ httpMethod: 'OPTIONS' }), ctx, () => {});
  expect(result?.statusCode).toBe(204);
});

test('POST /ai/chat returns reply from Bedrock', async () => {
  mockSend.mockResolvedValue({
    output: { message: { content: [{ text: 'Hello! How can I help?' }] } },
  });
  const result = await handler(
    makeEvent({ body: JSON.stringify({ message: 'Hello' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(200);
  const body = JSON.parse(result!.body);
  expect(body.reply).toBe('Hello! How can I help?');
  expect(body.modelId).toBe('anthropic.claude-3-haiku-20240307-v1:0');
});

test('POST /ai/chat includes conversation history in Bedrock request', async () => {
  mockSend.mockResolvedValue({
    output: { message: { content: [{ text: 'Standard rooms are available.' }] } },
  });
  const result = await handler(
    makeEvent({
      body: JSON.stringify({
        message: 'Are standard rooms available?',
        conversationHistory: [
          { role: 'user', content: 'Hi' },
          { role: 'assistant', content: 'Hello!' },
        ],
      }),
    }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(200);
  const sentCommand = mockSend.mock.calls[0][0];
  // 2 history entries + 1 new message = 3
  expect(sentCommand.input.messages).toHaveLength(3);
});

test('POST /ai/chat silently skips malformed history entries', async () => {
  mockSend.mockResolvedValue({
    output: { message: { content: [{ text: 'Sure!' }] } },
  });
  const result = await handler(
    makeEvent({
      body: JSON.stringify({
        message: 'Hello',
        conversationHistory: [
          { role: 'invalid-role', content: 'bad' },
          null,
          { role: 'user', content: 'valid' },
        ],
      }),
    }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(200);
  const sentCommand = mockSend.mock.calls[0][0];
  // Only the 1 valid history entry + 1 new message
  expect(sentCommand.input.messages).toHaveLength(2);
});

test('POST /ai/chat returns 400 for missing message field', async () => {
  const result = await handler(makeEvent({ body: JSON.stringify({}) }), ctx, () => {});
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/chat returns 400 for whitespace-only message', async () => {
  const result = await handler(
    makeEvent({ body: JSON.stringify({ message: '   ' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/chat returns 400 for invalid JSON body', async () => {
  const result = await handler(makeEvent({ body: 'not-json' }), ctx, () => {});
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/chat returns 500 when Bedrock throws', async () => {
  mockSend.mockRejectedValue(new Error('Bedrock unavailable'));
  const result = await handler(
    makeEvent({ body: JSON.stringify({ message: 'Hello' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(500);
});
